import { useEffect, useMemo, useRef, useState, useCallback } from "react";
import { Link } from "@/lib/router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { dashboardApi } from "../api/dashboard";
import { activityApi } from "../api/activity";
import { issuesApi } from "../api/issues";
import { agentsApi } from "../api/agents";
import { projectsApi } from "../api/projects";
import { heartbeatsApi } from "../api/heartbeats";
import { useCompany } from "../context/CompanyContext";
import { useDialog } from "../context/DialogContext";
import { useBreadcrumbs } from "../context/BreadcrumbContext";
import { queryKeys } from "../lib/queryKeys";
import { MetricCard } from "../components/MetricCard";
import { EmptyState } from "../components/EmptyState";
import { StatusIcon } from "../components/StatusIcon";
import { PriorityIcon } from "../components/PriorityIcon";
import { ActivityRow } from "../components/ActivityRow";
import { Identity } from "../components/Identity";
import { timeAgo } from "../lib/timeAgo";
import { cn, formatCents } from "../lib/utils";
import { Bot, CircleDot, DollarSign, ShieldCheck, LayoutDashboard, PauseCircle, Crown, Zap, Square } from "lucide-react";
import { ActiveAgentsPanel } from "../components/ActiveAgentsPanel";
import { ChartCard, RunActivityChart, PriorityChart, IssueStatusChart, SuccessRateChart } from "../components/ActivityCharts";
import { PageSkeleton } from "../components/PageSkeleton";
import type { Agent, Issue } from "@paperclipai/shared";
import { PluginSlotOutlet } from "@/plugins/slots";

const DURATION_PRESETS = [
  { label: "2h", hours: 2 },
  { label: "4h", hours: 4 },
  { label: "6h", hours: 6 },
  { label: "8h", hours: 8 },
  { label: "12h", hours: 12 },
];

function formatCountdown(ms: number): string {
  if (ms <= 0) return "0:00:00";
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

function useLiveCountdown(expiresAt: string | null): number {
  const [remaining, setRemaining] = useState(() => {
    if (!expiresAt) return 0;
    return Math.max(0, new Date(expiresAt).getTime() - Date.now());
  });

  useEffect(() => {
    if (!expiresAt) { setRemaining(0); return; }
    const target = new Date(expiresAt).getTime();
    const update = () => setRemaining(Math.max(0, target - Date.now()));
    update();
    const id = setInterval(update, 1000);
    return () => clearInterval(id);
  }, [expiresAt]);

  return remaining;
}

function getRecentIssues(issues: Issue[]): Issue[] {
  return [...issues]
    .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
}

export function Dashboard() {
  const { selectedCompanyId, companies } = useCompany();
  const { openOnboarding } = useDialog();
  const { setBreadcrumbs } = useBreadcrumbs();
  const [animatedActivityIds, setAnimatedActivityIds] = useState<Set<string>>(new Set());
  const seenActivityIdsRef = useRef<Set<string>>(new Set());
  const hydratedActivityRef = useRef(false);
  const activityAnimationTimersRef = useRef<number[]>([]);

  const queryClient = useQueryClient();

  const { data: agents } = useQuery({
    queryKey: queryKeys.agents.list(selectedCompanyId!),
    queryFn: () => agentsApi.list(selectedCompanyId!),
    enabled: !!selectedCompanyId,
  });

  const ceoAgent = useMemo(
    () => (agents ?? []).find((a) => a.role === "ceo" && a.status !== "terminated"),
    [agents],
  );

  const selfGovData = (ceoAgent?.metadata as Record<string, unknown> | null)?.selfGoverning as
    | { expiresAt: string; condition?: string }
    | null
    | undefined;
  const selfGovExpiresAt = selfGovData?.expiresAt ?? null;
  const selfGovCondition = selfGovData?.condition ?? null;
  const selfGovRemaining = useLiveCountdown(selfGovExpiresAt);
  const selfGoverning = selfGovRemaining > 0;

  const [selectedHours, setSelectedHours] = useState(6);
  const [conditionText, setConditionText] = useState("");
  const [sgMode, setSgMode] = useState<"timer" | "condition">("timer");

  const startSelfGoverning = useMutation({
    mutationFn: async (args: { hours: number; condition?: string }) => {
      if (!ceoAgent) return;
      const expiresAt = new Date(Date.now() + args.hours * 3600_000).toISOString();
      const sgPayload: Record<string, unknown> = { expiresAt };
      if (args.condition?.trim()) {
        sgPayload.condition = args.condition.trim();
      }
      await agentsApi.update(ceoAgent.id, {
        metadata: { ...(ceoAgent.metadata as Record<string, unknown> | null ?? {}), selfGoverning: sgPayload },
      }, selectedCompanyId ?? undefined);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.agents.list(selectedCompanyId!) });
      setConditionText("");
    },
  });

  const stopSelfGoverning = useMutation({
    mutationFn: async () => {
      if (!ceoAgent) return;
      const meta = { ...(ceoAgent.metadata as Record<string, unknown> | null ?? {}) };
      delete meta.selfGoverning;
      await agentsApi.update(ceoAgent.id, { metadata: meta }, selectedCompanyId ?? undefined);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.agents.list(selectedCompanyId!) });
    },
  });

  const liveAgents = useMemo(
    () => (agents ?? []).filter((a) => a.status !== "terminated"),
    [agents],
  );

  const gigaModeOn = liveAgents.length > 0 &&
    liveAgents.every((a) => !!(a.metadata as Record<string, unknown> | null)?.gigaMode);

  const toggleGigaMode = useMutation({
    mutationFn: async () => {
      const newValue = !gigaModeOn;
      await Promise.allSettled(
        liveAgents.map((a) =>
          agentsApi.update(a.id, {
            metadata: { ...(a.metadata as Record<string, unknown> | null ?? {}), gigaMode: newValue },
          }, selectedCompanyId ?? undefined),
        ),
      );
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.agents.list(selectedCompanyId!) });
    },
  });

  useEffect(() => {
    setBreadcrumbs([{ label: "Dashboard" }]);
  }, [setBreadcrumbs]);

  const { data, isLoading, error } = useQuery({
    queryKey: queryKeys.dashboard(selectedCompanyId!),
    queryFn: () => dashboardApi.summary(selectedCompanyId!),
    enabled: !!selectedCompanyId,
  });

  const { data: activity } = useQuery({
    queryKey: queryKeys.activity(selectedCompanyId!),
    queryFn: () => activityApi.list(selectedCompanyId!),
    enabled: !!selectedCompanyId,
  });

  const { data: issues } = useQuery({
    queryKey: queryKeys.issues.list(selectedCompanyId!),
    queryFn: () => issuesApi.list(selectedCompanyId!),
    enabled: !!selectedCompanyId,
  });

  const { data: projects } = useQuery({
    queryKey: queryKeys.projects.list(selectedCompanyId!),
    queryFn: () => projectsApi.list(selectedCompanyId!),
    enabled: !!selectedCompanyId,
  });

  const { data: runs } = useQuery({
    queryKey: queryKeys.heartbeats(selectedCompanyId!),
    queryFn: () => heartbeatsApi.list(selectedCompanyId!),
    enabled: !!selectedCompanyId,
  });

  const recentIssues = issues ? getRecentIssues(issues) : [];
  const recentActivity = useMemo(() => (activity ?? []).slice(0, 10), [activity]);

  useEffect(() => {
    for (const timer of activityAnimationTimersRef.current) {
      window.clearTimeout(timer);
    }
    activityAnimationTimersRef.current = [];
    seenActivityIdsRef.current = new Set();
    hydratedActivityRef.current = false;
    setAnimatedActivityIds(new Set());
  }, [selectedCompanyId]);

  useEffect(() => {
    if (recentActivity.length === 0) return;

    const seen = seenActivityIdsRef.current;
    const currentIds = recentActivity.map((event) => event.id);

    if (!hydratedActivityRef.current) {
      for (const id of currentIds) seen.add(id);
      hydratedActivityRef.current = true;
      return;
    }

    const newIds = currentIds.filter((id) => !seen.has(id));
    if (newIds.length === 0) {
      for (const id of currentIds) seen.add(id);
      return;
    }

    setAnimatedActivityIds((prev) => {
      const next = new Set(prev);
      for (const id of newIds) next.add(id);
      return next;
    });

    for (const id of newIds) seen.add(id);

    const timer = window.setTimeout(() => {
      setAnimatedActivityIds((prev) => {
        const next = new Set(prev);
        for (const id of newIds) next.delete(id);
        return next;
      });
      activityAnimationTimersRef.current = activityAnimationTimersRef.current.filter((t) => t !== timer);
    }, 980);
    activityAnimationTimersRef.current.push(timer);
  }, [recentActivity]);

  useEffect(() => {
    return () => {
      for (const timer of activityAnimationTimersRef.current) {
        window.clearTimeout(timer);
      }
    };
  }, []);

  const agentMap = useMemo(() => {
    const map = new Map<string, Agent>();
    for (const a of agents ?? []) map.set(a.id, a);
    return map;
  }, [agents]);

  const entityNameMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const i of issues ?? []) map.set(`issue:${i.id}`, i.identifier ?? i.id.slice(0, 8));
    for (const a of agents ?? []) map.set(`agent:${a.id}`, a.name);
    for (const p of projects ?? []) map.set(`project:${p.id}`, p.name);
    return map;
  }, [issues, agents, projects]);

  const entityTitleMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const i of issues ?? []) map.set(`issue:${i.id}`, i.title);
    return map;
  }, [issues]);

  const agentName = (id: string | null) => {
    if (!id || !agents) return null;
    return agents.find((a) => a.id === id)?.name ?? null;
  };

  if (!selectedCompanyId) {
    if (companies.length === 0) {
      return (
        <EmptyState
          icon={LayoutDashboard}
          message="Welcome to Paperclip. Set up your first company and agent to get started."
          action="Get Started"
          onAction={openOnboarding}
        />
      );
    }
    return (
      <EmptyState icon={LayoutDashboard} message="Create or select a company to view the dashboard." />
    );
  }

  if (isLoading) {
    return <PageSkeleton variant="dashboard" />;
  }

  const hasNoAgents = agents !== undefined && agents.length === 0;

  return (
    <div className="space-y-6">
      {error && <p className="text-sm text-destructive">{error.message}</p>}

      {hasNoAgents && (
        <div className="flex items-center justify-between gap-3 rounded-md border border-amber-300 bg-amber-50 px-4 py-3 dark:border-amber-500/25 dark:bg-amber-950/60">
          <div className="flex items-center gap-2.5">
            <Bot className="h-4 w-4 text-amber-600 dark:text-amber-400 shrink-0" />
            <p className="text-sm text-amber-900 dark:text-amber-100">
              You have no agents.
            </p>
          </div>
          <button
            onClick={() => openOnboarding({ initialStep: 2, companyId: selectedCompanyId! })}
            className="text-sm font-medium text-amber-700 hover:text-amber-900 dark:text-amber-300 dark:hover:text-amber-100 underline underline-offset-2 shrink-0"
          >
            Create one here
          </button>
        </div>
      )}

      <ActiveAgentsPanel companyId={selectedCompanyId!} />

      {ceoAgent && (
        <div className={cn(
          "border px-4 py-3 transition-colors",
          selfGoverning
            ? "border-emerald-500/30 bg-emerald-500/5"
            : "border-border bg-card"
        )}>
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <Crown className={cn(
                "h-4 w-4 shrink-0",
                selfGoverning ? "text-emerald-500" : "text-muted-foreground"
              )} />
              <div>
                <p className={cn(
                  "text-sm font-medium",
                  selfGoverning ? "text-emerald-700 dark:text-emerald-300" : "text-foreground"
                )}>
                  Self-Governing Mode
                </p>
                <p className="text-xs text-muted-foreground">
                  {selfGoverning
                    ? "CEO is autonomously reviewing progress, creating tasks, and delegating work."
                    : "CEO exits heartbeat when no tasks are assigned. Set a timer to let the CEO work autonomously."}
                </p>
              </div>
            </div>

            {selfGoverning && (
              <div className="flex items-center gap-3 shrink-0">
                <div className="text-right">
                  <p className="text-lg font-mono font-semibold text-emerald-600 dark:text-emerald-400 tabular-nums">
                    {formatCountdown(selfGovRemaining)}
                  </p>
                  <p className="text-[10px] text-muted-foreground uppercase tracking-wider">remaining</p>
                </div>
                <button
                  onClick={() => stopSelfGoverning.mutate()}
                  disabled={stopSelfGoverning.isPending}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium border border-red-300 dark:border-red-500/30 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors"
                >
                  <Square className="h-3 w-3" />
                  Stop
                </button>
              </div>
            )}
          </div>

          {selfGoverning && selfGovCondition && (
            <div className="mt-2 px-2 py-1.5 bg-emerald-500/10 border border-emerald-500/20 text-xs text-emerald-700 dark:text-emerald-300">
              <span className="font-medium">Goal:</span> {selfGovCondition}
            </div>
          )}

          {!selfGoverning && (
            <div className="mt-3 pt-3 border-t border-border/50 space-y-3">
              <div className="flex items-center gap-1">
                <button
                  onClick={() => setSgMode("timer")}
                  className={cn(
                    "px-3 py-1 text-xs font-medium transition-colors",
                    sgMode === "timer"
                      ? "bg-emerald-500 text-white"
                      : "bg-muted text-muted-foreground hover:bg-accent hover:text-foreground"
                  )}
                >
                  Timer
                </button>
                <button
                  onClick={() => setSgMode("condition")}
                  className={cn(
                    "px-3 py-1 text-xs font-medium transition-colors",
                    sgMode === "condition"
                      ? "bg-emerald-500 text-white"
                      : "bg-muted text-muted-foreground hover:bg-accent hover:text-foreground"
                  )}
                >
                  Until condition
                </button>
              </div>

              {sgMode === "timer" && (
                <div className="flex items-center gap-2">
                  <div className="flex items-center gap-1">
                    {DURATION_PRESETS.map((p) => (
                      <button
                        key={p.hours}
                        onClick={() => setSelectedHours(p.hours)}
                        className={cn(
                          "px-2.5 py-1 text-xs font-medium transition-colors",
                          selectedHours === p.hours
                            ? "bg-emerald-500 text-white"
                            : "bg-muted text-muted-foreground hover:bg-accent hover:text-foreground"
                        )}
                      >
                        {p.label}
                      </button>
                    ))}
                  </div>
                  <button
                    onClick={() => startSelfGoverning.mutate({ hours: selectedHours })}
                    disabled={startSelfGoverning.isPending}
                    className={cn(
                      "ml-auto flex items-center gap-1.5 px-4 py-1.5 text-xs font-medium transition-colors",
                      "bg-emerald-500 text-white hover:bg-emerald-600",
                      "disabled:opacity-50 disabled:cursor-not-allowed"
                    )}
                  >
                    <Crown className="h-3 w-3" />
                    {startSelfGoverning.isPending ? "Starting…" : "Start"}
                  </button>
                </div>
              )}

              {sgMode === "condition" && (
                <div className="space-y-2">
                  <input
                    type="text"
                    value={conditionText}
                    onChange={(e) => setConditionText(e.target.value)}
                    placeholder="e.g. CEO is highly confident M2 is complete"
                    className="w-full px-3 py-2 text-sm border border-border bg-background placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-emerald-500"
                  />
                  <div className="flex items-center gap-2">
                    <p className="text-[10px] text-muted-foreground flex-1">
                      Max runtime safety limit:
                    </p>
                    <div className="flex items-center gap-1">
                      {DURATION_PRESETS.map((p) => (
                        <button
                          key={p.hours}
                          onClick={() => setSelectedHours(p.hours)}
                          className={cn(
                            "px-2 py-0.5 text-[10px] font-medium transition-colors",
                            selectedHours === p.hours
                              ? "bg-emerald-500 text-white"
                              : "bg-muted text-muted-foreground hover:bg-accent hover:text-foreground"
                          )}
                        >
                          {p.label}
                        </button>
                      ))}
                    </div>
                    <button
                      onClick={() => startSelfGoverning.mutate({ hours: selectedHours, condition: conditionText })}
                      disabled={startSelfGoverning.isPending || !conditionText.trim()}
                      className={cn(
                        "flex items-center gap-1.5 px-4 py-1.5 text-xs font-medium transition-colors",
                        "bg-emerald-500 text-white hover:bg-emerald-600",
                        "disabled:opacity-50 disabled:cursor-not-allowed"
                      )}
                    >
                      <Crown className="h-3 w-3" />
                      {startSelfGoverning.isPending ? "Starting…" : "Start"}
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {liveAgents.length > 0 && (
        <div className={cn(
          "flex items-center justify-between gap-3 border px-4 py-3 transition-colors",
          gigaModeOn
            ? "border-amber-500/30 bg-amber-500/5"
            : "border-border bg-card"
        )}>
          <div className="flex items-center gap-2.5">
            <Zap className={cn(
              "h-4 w-4 shrink-0",
              gigaModeOn ? "text-amber-500" : "text-muted-foreground"
            )} />
            <div>
              <p className={cn(
                "text-sm font-medium",
                gigaModeOn ? "text-amber-700 dark:text-amber-300" : "text-foreground"
              )}>
                Giga Mode
              </p>
              <p className="text-xs text-muted-foreground">
                {gigaModeOn
                  ? "Agents power through their inbox — completing tasks back-to-back without waiting for the next heartbeat."
                  : "Agents complete one task per heartbeat, then exit. Enable to let agents work through multiple tasks per run."}
              </p>
            </div>
          </div>
          <button
            onClick={() => toggleGigaMode.mutate()}
            disabled={toggleGigaMode.isPending}
            className={cn(
              "relative inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50",
              gigaModeOn ? "bg-amber-500" : "bg-muted"
            )}
          >
            <span className={cn(
              "pointer-events-none block h-4 w-4 rounded-full bg-white shadow-sm ring-0 transition-transform",
              gigaModeOn ? "translate-x-5" : "translate-x-0.5"
            )} />
          </button>
        </div>
      )}

      {data && (
        <>
          {data.budgets.activeIncidents > 0 ? (
            <div className="flex items-start justify-between gap-3 rounded-xl border border-red-500/20 bg-[linear-gradient(180deg,rgba(255,80,80,0.12),rgba(255,255,255,0.02))] px-4 py-3">
              <div className="flex items-start gap-2.5">
                <PauseCircle className="mt-0.5 h-4 w-4 shrink-0 text-red-300" />
                <div>
                  <p className="text-sm font-medium text-red-50">
                    {data.budgets.activeIncidents} active budget incident{data.budgets.activeIncidents === 1 ? "" : "s"}
                  </p>
                  <p className="text-xs text-red-100/70">
                    {data.budgets.pausedAgents} agents paused · {data.budgets.pausedProjects} projects paused · {data.budgets.pendingApprovals} pending budget approvals
                  </p>
                </div>
              </div>
              <Link to="/costs" className="text-sm underline underline-offset-2 text-red-100">
                Open budgets
              </Link>
            </div>
          ) : null}

          <div className="grid grid-cols-2 xl:grid-cols-4 gap-1 sm:gap-2">
            <MetricCard
              icon={Bot}
              value={data.agents.active + data.agents.running + data.agents.paused + data.agents.error}
              label="Agents Enabled"
              to="/agents"
              description={
                <span>
                  {data.agents.running} running{", "}
                  {data.agents.paused} paused{", "}
                  {data.agents.error} errors
                </span>
              }
            />
            <MetricCard
              icon={CircleDot}
              value={data.tasks.inProgress}
              label="Tasks In Progress"
              to="/issues"
              description={
                <span>
                  {data.tasks.open} open{", "}
                  {data.tasks.blocked} blocked
                </span>
              }
            />
            <MetricCard
              icon={DollarSign}
              value={formatCents(data.costs.monthSpendCents)}
              label="Month Spend"
              to="/costs"
              description={
                <span>
                  {data.costs.monthBudgetCents > 0
                    ? `${data.costs.monthUtilizationPercent}% of ${formatCents(data.costs.monthBudgetCents)} budget`
                    : "Unlimited budget"}
                </span>
              }
            />
            <MetricCard
              icon={ShieldCheck}
              value={data.pendingApprovals + data.budgets.pendingApprovals}
              label="Pending Approvals"
              to="/approvals"
              description={
                <span>
                  {data.budgets.pendingApprovals > 0
                    ? `${data.budgets.pendingApprovals} budget overrides awaiting board review`
                    : "Awaiting board review"}
                </span>
              }
            />
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <ChartCard title="Run Activity" subtitle="Last 14 days">
              <RunActivityChart runs={runs ?? []} />
            </ChartCard>
            <ChartCard title="Issues by Priority" subtitle="Last 14 days">
              <PriorityChart issues={issues ?? []} />
            </ChartCard>
            <ChartCard title="Issues by Status" subtitle="Last 14 days">
              <IssueStatusChart issues={issues ?? []} />
            </ChartCard>
            <ChartCard title="Success Rate" subtitle="Last 14 days">
              <SuccessRateChart runs={runs ?? []} />
            </ChartCard>
          </div>

          <PluginSlotOutlet
            slotTypes={["dashboardWidget"]}
            context={{ companyId: selectedCompanyId }}
            className="grid gap-4 md:grid-cols-2"
            itemClassName="rounded-lg border bg-card p-4 shadow-sm"
          />

          <div className="grid md:grid-cols-2 gap-4">
            {/* Recent Activity */}
            {recentActivity.length > 0 && (
              <div className="min-w-0">
                <h3 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-3">
                  Recent Activity
                </h3>
                <div className="border border-border divide-y divide-border overflow-hidden">
                  {recentActivity.map((event) => (
                    <ActivityRow
                      key={event.id}
                      event={event}
                      agentMap={agentMap}
                      entityNameMap={entityNameMap}
                      entityTitleMap={entityTitleMap}
                      className={animatedActivityIds.has(event.id) ? "activity-row-enter" : undefined}
                    />
                  ))}
                </div>
              </div>
            )}

            {/* Recent Tasks */}
            <div className="min-w-0">
              <h3 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-3">
                Recent Tasks
              </h3>
              {recentIssues.length === 0 ? (
                <div className="border border-border p-4">
                  <p className="text-sm text-muted-foreground">No tasks yet.</p>
                </div>
              ) : (
                <div className="border border-border divide-y divide-border overflow-hidden">
                  {recentIssues.slice(0, 10).map((issue) => (
                    <Link
                      key={issue.id}
                      to={`/issues/${issue.identifier ?? issue.id}`}
                      className="px-4 py-3 text-sm cursor-pointer hover:bg-accent/50 transition-colors no-underline text-inherit block"
                    >
                      <div className="flex items-start gap-2 sm:items-center sm:gap-3">
                        {/* Status icon - left column on mobile */}
                        <span className="shrink-0 sm:hidden">
                          <StatusIcon status={issue.status} />
                        </span>

                        {/* Right column on mobile: title + metadata stacked */}
                        <span className="flex min-w-0 flex-1 flex-col gap-1 sm:contents">
                          <span className="line-clamp-2 text-sm sm:order-2 sm:flex-1 sm:min-w-0 sm:line-clamp-none sm:truncate">
                            {issue.title}
                          </span>
                          <span className="flex items-center gap-2 sm:order-1 sm:shrink-0">
                            <span className="hidden sm:inline-flex"><PriorityIcon priority={issue.priority} /></span>
                            <span className="hidden sm:inline-flex"><StatusIcon status={issue.status} /></span>
                            <span className="text-xs font-mono text-muted-foreground">
                              {issue.identifier ?? issue.id.slice(0, 8)}
                            </span>
                            {issue.assigneeAgentId && (() => {
                              const name = agentName(issue.assigneeAgentId);
                              return name
                                ? <span className="hidden sm:inline-flex"><Identity name={name} size="sm" /></span>
                                : null;
                            })()}
                            <span className="text-xs text-muted-foreground sm:hidden">&middot;</span>
                            <span className="text-xs text-muted-foreground shrink-0 sm:order-last">
                              {timeAgo(issue.updatedAt)}
                            </span>
                          </span>
                        </span>
                      </div>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>

        </>
      )}
    </div>
  );
}

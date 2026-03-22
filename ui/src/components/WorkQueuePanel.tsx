import { useState, useCallback, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { GripVertical, Trash2, X, ListOrdered } from "lucide-react";
import { agentsApi, type WorkQueueItem } from "../api/agents";
import { queryKeys } from "../lib/queryKeys";
import { cn } from "../lib/utils";
import { StatusBadge } from "./StatusBadge";
import { Link } from "react-router-dom";

const PRIORITY_COLORS: Record<string, string> = {
  critical: "bg-red-500/15 text-red-700 dark:text-red-400",
  high: "bg-orange-500/15 text-orange-700 dark:text-orange-400",
  medium: "bg-blue-500/15 text-blue-700 dark:text-blue-400",
  low: "bg-neutral-500/10 text-neutral-600 dark:text-neutral-400",
};

function PriorityBadge({ priority }: { priority: string | null }) {
  if (!priority) return null;
  return (
    <span className={cn("inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-medium", PRIORITY_COLORS[priority])}>
      {priority}
    </span>
  );
}

function SortableItem({
  item,
  selected,
  onToggle,
  onRemove,
}: {
  item: WorkQueueItem;
  selected: boolean;
  onToggle: (id: string) => void;
  onRemove: (id: string) => void;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: item.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "flex items-center gap-2 px-3 py-2 border-b border-border/50 last:border-b-0 transition-colors",
        isDragging && "bg-accent/50 shadow-sm z-10 relative",
        item.status === "locked" && "bg-cyan-500/5",
      )}
    >
      <input
        type="checkbox"
        checked={selected}
        onChange={() => onToggle(item.id)}
        className="h-3.5 w-3.5 rounded border-border accent-cyan-600 shrink-0"
      />
      <button
        {...attributes}
        {...listeners}
        className="cursor-grab active:cursor-grabbing text-muted-foreground hover:text-foreground shrink-0"
        tabIndex={-1}
      >
        <GripVertical className="h-3.5 w-3.5" />
      </button>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          {item.issueIdentifier && (
            <Link
              to={`/issues/${item.issueIdentifier}`}
              className="text-xs font-mono text-muted-foreground hover:text-foreground shrink-0"
            >
              {item.issueIdentifier}
            </Link>
          )}
          <span className="text-xs truncate">{item.issueTitle ?? "Untitled"}</span>
        </div>
      </div>
      <div className="flex items-center gap-1.5 shrink-0">
        <PriorityBadge priority={item.issuePriority} />
        {item.issueStatus && <StatusBadge status={item.issueStatus} />}
        {item.status === "locked" && (
          <span className="text-[9px] font-medium text-cyan-600 dark:text-cyan-400">ACTIVE</span>
        )}
        <span className="text-[10px] text-muted-foreground">{item.source}</span>
        <button
          onClick={() => onRemove(item.id)}
          className="p-0.5 text-muted-foreground hover:text-destructive transition-colors"
          title="Remove from queue"
        >
          <Trash2 className="h-3 w-3" />
        </button>
      </div>
    </div>
  );
}

export function WorkQueuePanel({
  agentId,
  companyId,
}: {
  agentId: string;
  companyId?: string;
}) {
  const queryClient = useQueryClient();
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [confirmClear, setConfirmClear] = useState(false);

  const { data: items = [], isLoading } = useQuery({
    queryKey: queryKeys.agents.workQueue(agentId),
    queryFn: () => agentsApi.workQueue(agentId, companyId),
    refetchInterval: 10_000,
  });

  const invalidate = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: queryKeys.agents.workQueue(agentId) });
  }, [queryClient, agentId]);

  const reorderMut = useMutation({
    mutationFn: (reordered: Array<{ id: string; queueOrder: number }>) =>
      agentsApi.workQueueReorder(agentId, reordered, companyId),
    onSuccess: invalidate,
  });

  const removeMut = useMutation({
    mutationFn: (itemId: string) => agentsApi.workQueueRemove(agentId, itemId, companyId),
    onSuccess: invalidate,
  });

  const clearAllMut = useMutation({
    mutationFn: () => agentsApi.workQueueClearAll(agentId, companyId),
    onSuccess: () => {
      setConfirmClear(false);
      setSelectedIds(new Set());
      invalidate();
    },
  });

  const removeSelectedMut = useMutation({
    mutationFn: async () => {
      for (const id of selectedIds) {
        await agentsApi.workQueueRemove(agentId, id, companyId);
      }
    },
    onSuccess: () => {
      setSelectedIds(new Set());
      invalidate();
    },
  });

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      if (!over || active.id === over.id) return;

      const oldIndex = items.findIndex((i) => i.id === active.id);
      const newIndex = items.findIndex((i) => i.id === over.id);
      if (oldIndex < 0 || newIndex < 0) return;

      const reordered = arrayMove(items, oldIndex, newIndex);
      const updates = reordered.map((item, idx) => ({
        id: item.id,
        queueOrder: idx * 10,
      }));
      reorderMut.mutate(updates);
    },
    [items, reorderMut],
  );

  const toggleSelect = useCallback((id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const allSelected = useMemo(
    () => items.length > 0 && items.every((i) => selectedIds.has(i.id)),
    [items, selectedIds],
  );

  const toggleAll = useCallback(() => {
    if (allSelected) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(items.map((i) => i.id)));
    }
  }, [allSelected, items]);

  const pendingItems = items.filter((i) => i.status === "pending" || i.status === "locked");

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <ListOrdered className="h-4 w-4 text-muted-foreground" />
          <h3 className="text-sm font-medium">
            Work Queue
            {pendingItems.length > 0 && (
              <span className="ml-1.5 text-xs text-muted-foreground font-normal">
                ({pendingItems.length})
              </span>
            )}
          </h3>
        </div>
        <div className="flex items-center gap-1.5">
          {selectedIds.size > 0 && (
            <button
              onClick={() => removeSelectedMut.mutate()}
              disabled={removeSelectedMut.isPending}
              className="inline-flex items-center gap-1 rounded border border-destructive/30 bg-destructive/5 px-2 py-1 text-[10px] font-medium text-destructive transition-colors hover:bg-destructive/10"
            >
              <Trash2 className="h-2.5 w-2.5" />
              Remove {selectedIds.size}
            </button>
          )}
          {pendingItems.length > 0 && (
            confirmClear ? (
              <div className="flex items-center gap-1">
                <button
                  onClick={() => clearAllMut.mutate()}
                  disabled={clearAllMut.isPending}
                  className="inline-flex items-center gap-1 rounded border border-destructive/30 bg-destructive/5 px-2 py-1 text-[10px] font-medium text-destructive transition-colors hover:bg-destructive/10"
                >
                  Confirm
                </button>
                <button
                  onClick={() => setConfirmClear(false)}
                  className="inline-flex items-center rounded p-1 text-muted-foreground hover:text-foreground"
                >
                  <X className="h-3 w-3" />
                </button>
              </div>
            ) : (
              <button
                onClick={() => setConfirmClear(true)}
                className="inline-flex items-center gap-1 rounded border border-border/70 bg-background/70 px-2 py-1 text-[10px] text-muted-foreground transition-colors hover:text-foreground"
              >
                Clear All
              </button>
            )
          )}
        </div>
      </div>

      {isLoading ? (
        <div className="border border-border rounded-lg p-4 text-center text-xs text-muted-foreground">
          Loading queue...
        </div>
      ) : pendingItems.length === 0 ? (
        <div className="border border-border rounded-lg p-4 text-center text-xs text-muted-foreground">
          Queue is empty. Issues assigned to this agent will appear here.
        </div>
      ) : (
        <div className="border border-border rounded-lg overflow-hidden">
          <div className="flex items-center gap-2 px-3 py-1.5 border-b border-border bg-muted/30">
            <input
              type="checkbox"
              checked={allSelected}
              onChange={toggleAll}
              className="h-3 w-3 rounded border-border accent-cyan-600"
            />
            <span className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider">
              Issue
            </span>
          </div>
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={pendingItems.map((i) => i.id)}
              strategy={verticalListSortingStrategy}
            >
              {pendingItems.map((item) => (
                <SortableItem
                  key={item.id}
                  item={item}
                  selected={selectedIds.has(item.id)}
                  onToggle={toggleSelect}
                  onRemove={(id) => removeMut.mutate(id)}
                />
              ))}
            </SortableContext>
          </DndContext>
        </div>
      )}
    </div>
  );
}

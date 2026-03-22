import { pgTable, uuid, text, timestamp, integer, index } from "drizzle-orm/pg-core";
import { companies } from "./companies.js";
import { agents } from "./agents.js";
import { issues } from "./issues.js";
import { heartbeatRuns } from "./heartbeat_runs.js";

export const agentWorkQueue = pgTable(
  "agent_work_queue",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    companyId: uuid("company_id").notNull().references(() => companies.id),
    agentId: uuid("agent_id").notNull().references(() => agents.id),
    issueId: uuid("issue_id").references(() => issues.id, { onDelete: "cascade" }),
    /** Lower value = higher priority. Derived from issue priority + timestamp offset. */
    queueOrder: integer("queue_order").notNull().default(200),
    /** assignment | mention | manual | system */
    source: text("source").notNull().default("system"),
    /** pending | locked | completed | removed */
    status: text("status").notNull().default("pending"),
    lockedRunId: uuid("locked_run_id").references(() => heartbeatRuns.id, { onDelete: "set null" }),
    addedAt: timestamp("added_at", { withTimezone: true }).notNull().defaultNow(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    companyAgentStatusIdx: index("agent_work_queue_company_agent_status_idx").on(
      table.companyId,
      table.agentId,
      table.status,
    ),
    agentOrderIdx: index("agent_work_queue_agent_order_idx").on(
      table.agentId,
      table.queueOrder,
    ),
    issueIdx: index("agent_work_queue_issue_idx").on(table.issueId),
  }),
);

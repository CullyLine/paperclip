CREATE TABLE "agent_work_queue" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"company_id" uuid NOT NULL,
	"agent_id" uuid NOT NULL,
	"issue_id" uuid,
	"queue_order" integer DEFAULT 200 NOT NULL,
	"source" text DEFAULT 'system' NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"locked_run_id" uuid,
	"added_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "agent_runtime_state" ADD COLUMN "velocity_window_start" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "agent_runtime_state" ADD COLUMN "velocity_window_tokens" bigint DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "agent_runtime_state" ADD COLUMN "velocity_window_runs" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "agent_task_sessions" ADD COLUMN "last_knowledge_state" jsonb;--> statement-breakpoint
ALTER TABLE "agent_work_queue" ADD CONSTRAINT "agent_work_queue_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_work_queue" ADD CONSTRAINT "agent_work_queue_agent_id_agents_id_fk" FOREIGN KEY ("agent_id") REFERENCES "public"."agents"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_work_queue" ADD CONSTRAINT "agent_work_queue_issue_id_issues_id_fk" FOREIGN KEY ("issue_id") REFERENCES "public"."issues"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_work_queue" ADD CONSTRAINT "agent_work_queue_locked_run_id_heartbeat_runs_id_fk" FOREIGN KEY ("locked_run_id") REFERENCES "public"."heartbeat_runs"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "agent_work_queue_company_agent_status_idx" ON "agent_work_queue" USING btree ("company_id","agent_id","status");--> statement-breakpoint
CREATE INDEX "agent_work_queue_agent_order_idx" ON "agent_work_queue" USING btree ("agent_id","queue_order");--> statement-breakpoint
CREATE INDEX "agent_work_queue_issue_idx" ON "agent_work_queue" USING btree ("issue_id");
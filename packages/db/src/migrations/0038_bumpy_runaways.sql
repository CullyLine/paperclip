ALTER TABLE "agents" ADD COLUMN "run_mode" text DEFAULT 'heartbeat' NOT NULL;--> statement-breakpoint
ALTER TABLE "agents" ADD COLUMN "last_booted_context_fingerprint" text;--> statement-breakpoint
ALTER TABLE "agents" ADD COLUMN "current_run_session_id" text;--> statement-breakpoint
ALTER TABLE "agents" ADD COLUMN "reboot_pending" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "agents" ADD COLUMN "auto_reboot_on_context_change" boolean DEFAULT false NOT NULL;
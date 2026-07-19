ALTER TABLE `sessions` ADD `scope` text DEFAULT 'public' NOT NULL;--> statement-breakpoint
ALTER TABLE `sessions` ADD `remembered` integer DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE `sessions` ADD `idle_expires_at` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `sessions` ADD `authenticated_at` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `sessions` ADD `last_seen_at` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
UPDATE `sessions` SET `remembered` = CASE WHEN `expires_at` - `created_at` > 172800000 THEN 1 ELSE 0 END;--> statement-breakpoint
UPDATE `sessions` SET `authenticated_at` = `created_at`, `last_seen_at` = `created_at`, `idle_expires_at` = MIN(`expires_at`, `created_at` + 7200000);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `sessions_user_idx` ON `sessions` (`user_id`);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `sessions_expiry_idx` ON `sessions` (`expires_at`);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `sessions_idle_expiry_idx` ON `sessions` (`idle_expires_at`);

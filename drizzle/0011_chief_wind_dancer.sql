CREATE TABLE `series_subscriptions` (
	`user_id` text NOT NULL,
	`series_slug` text NOT NULL,
	`notify_new_episodes` integer DEFAULT false NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `series_slug`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `series_subscriptions_series_idx` ON `series_subscriptions` (`series_slug`,`notify_new_episodes`);--> statement-breakpoint
ALTER TABLE `notification_outbox` ADD `dedupe_key` text;--> statement-breakpoint
CREATE UNIQUE INDEX `notification_outbox_dedupe_unique` ON `notification_outbox` (`dedupe_key`);
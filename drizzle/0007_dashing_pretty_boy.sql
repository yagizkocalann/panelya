CREATE TABLE `preview_tokens` (
	`id` text PRIMARY KEY NOT NULL,
	`token_hash` text NOT NULL,
	`series_slug` text NOT NULL,
	`episode_slug` text,
	`created_by_user_id` text,
	`expires_at` integer NOT NULL,
	`revoked_at` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`series_slug`) REFERENCES `content_series`(`slug`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `preview_tokens_hash_unique` ON `preview_tokens` (`token_hash`);--> statement-breakpoint
CREATE INDEX `preview_tokens_scope_idx` ON `preview_tokens` (`series_slug`,`episode_slug`,`expires_at`);--> statement-breakpoint
CREATE INDEX `preview_tokens_expiry_idx` ON `preview_tokens` (`expires_at`);
CREATE TABLE `device_push_tokens` (
	`id` text PRIMARY KEY NOT NULL,
	`token` text NOT NULL,
	`platform` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `device_push_tokens_token_unique` ON `device_push_tokens` (`token`);
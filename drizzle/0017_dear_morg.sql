CREATE TABLE `account_deletion_requests` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`status` text DEFAULT 'pending' NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`last_error` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`completed_at` integer
);
--> statement-breakpoint
CREATE INDEX `account_deletion_requests_user_idx` ON `account_deletion_requests` (`user_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `account_deletion_requests_status_idx` ON `account_deletion_requests` (`status`,`updated_at`);--> statement-breakpoint
CREATE TABLE `account_reauthentication_requests` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`purpose` text NOT NULL,
	`transport` text NOT NULL,
	`client_id` text NOT NULL,
	`redirect_uri` text NOT NULL,
	`code_challenge` text NOT NULL,
	`state_hash` text NOT NULL,
	`nonce_hash` text NOT NULL,
	`expires_at` integer NOT NULL,
	`used_at` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `account_reauthentication_requests_state_unique` ON `account_reauthentication_requests` (`state_hash`);--> statement-breakpoint
CREATE INDEX `account_reauthentication_requests_expiry_idx` ON `account_reauthentication_requests` (`expires_at`);--> statement-breakpoint
CREATE TABLE `account_reauthentication_tokens` (
	`token_hash` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`purpose` text NOT NULL,
	`expires_at` integer NOT NULL,
	`used_at` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `account_reauthentication_tokens_expiry_idx` ON `account_reauthentication_tokens` (`expires_at`);--> statement-breakpoint
ALTER TABLE `provider_identities` ADD `provider_kind` text DEFAULT 'other_social' NOT NULL;--> statement-breakpoint
ALTER TABLE `users` ADD `status` text DEFAULT 'active' NOT NULL;--> statement-breakpoint
ALTER TABLE `users` ADD `sessions_valid_after` integer DEFAULT 0 NOT NULL;
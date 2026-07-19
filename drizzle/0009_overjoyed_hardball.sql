CREATE TABLE `admin_invitations` (
	`id` text PRIMARY KEY NOT NULL,
	`email` text NOT NULL,
	`token_hash` text NOT NULL,
	`invited_by_user_id` text,
	`status` text DEFAULT 'pending' NOT NULL,
	`expires_at` integer NOT NULL,
	`accepted_at` integer,
	`revoked_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`invited_by_user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `admin_invitations_token_unique` ON `admin_invitations` (`token_hash`);--> statement-breakpoint
CREATE UNIQUE INDEX `admin_invitations_pending_email_unique` ON `admin_invitations` (`email`) WHERE "admin_invitations"."status" = 'pending';--> statement-breakpoint
CREATE INDEX `admin_invitations_email_status_idx` ON `admin_invitations` (`email`,`status`,`created_at`);--> statement-breakpoint
CREATE INDEX `admin_invitations_expiry_idx` ON `admin_invitations` (`expires_at`);
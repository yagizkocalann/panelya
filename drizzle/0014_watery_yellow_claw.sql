CREATE TABLE `copyright_notices` (
	`id` text PRIMARY KEY NOT NULL,
	`reference_code` text NOT NULL,
	`access_token_hash` text NOT NULL,
	`claimant_name` text NOT NULL,
	`claimant_email` text NOT NULL,
	`claimant_role` text NOT NULL,
	`work_description` text NOT NULL,
	`original_work_url` text,
	`content_url` text NOT NULL,
	`rights_explanation` text NOT NULL,
	`status` text DEFAULT 'submitted' NOT NULL,
	`public_response` text,
	`access_expires_at` integer NOT NULL,
	`resolved_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `copyright_notices_reference_unique` ON `copyright_notices` (`reference_code`);--> statement-breakpoint
CREATE UNIQUE INDEX `copyright_notices_access_token_unique` ON `copyright_notices` (`access_token_hash`);--> statement-breakpoint
CREATE INDEX `copyright_notices_status_idx` ON `copyright_notices` (`status`,`created_at`);--> statement-breakpoint
CREATE INDEX `copyright_notices_access_expiry_idx` ON `copyright_notices` (`access_expires_at`);
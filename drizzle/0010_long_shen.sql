ALTER TABLE `media_derivative_jobs` ADD `dispatch_mode` text DEFAULT 'local_browser' NOT NULL;--> statement-breakpoint
ALTER TABLE `media_derivative_jobs` ADD `dispatch_status` text DEFAULT 'local' NOT NULL;--> statement-breakpoint
ALTER TABLE `media_derivative_jobs` ADD `dispatch_attempts` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `media_derivative_jobs` ADD `dispatch_error` text;--> statement-breakpoint
ALTER TABLE `media_derivative_jobs` ADD `dispatched_at` integer;--> statement-breakpoint
CREATE INDEX `media_derivative_jobs_dispatch_idx` ON `media_derivative_jobs` (`dispatch_status`,`created_at`);
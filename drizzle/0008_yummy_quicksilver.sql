CREATE TABLE `media_derivative_jobs` (
	`id` text PRIMARY KEY NOT NULL,
	`asset_id` text NOT NULL,
	`target_width` integer NOT NULL,
	`format` text DEFAULT 'webp' NOT NULL,
	`status` text DEFAULT 'queued' NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`error` text,
	`created_at` integer NOT NULL,
	`started_at` integer,
	`completed_at` integer,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`asset_id`) REFERENCES `media_assets`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `media_derivative_jobs_target_unique` ON `media_derivative_jobs` (`asset_id`,`target_width`,`format`);--> statement-breakpoint
CREATE INDEX `media_derivative_jobs_status_idx` ON `media_derivative_jobs` (`status`,`created_at`);--> statement-breakpoint
CREATE TABLE `media_variants` (
	`id` text PRIMARY KEY NOT NULL,
	`asset_id` text NOT NULL,
	`storage_key` text NOT NULL,
	`mime_type` text NOT NULL,
	`byte_size` integer NOT NULL,
	`width` integer NOT NULL,
	`height` integer NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`asset_id`) REFERENCES `media_assets`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `media_variants_asset_width_unique` ON `media_variants` (`asset_id`,`width`,`mime_type`);--> statement-breakpoint
CREATE UNIQUE INDEX `media_variants_storage_key_unique` ON `media_variants` (`storage_key`);--> statement-breakpoint
CREATE INDEX `media_variants_asset_idx` ON `media_variants` (`asset_id`,`width`);
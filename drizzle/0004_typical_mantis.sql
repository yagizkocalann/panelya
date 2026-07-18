CREATE TABLE `content_episodes` (
	`id` text PRIMARY KEY NOT NULL,
	`series_slug` text NOT NULL,
	`slug` text NOT NULL,
	`number` integer NOT NULL,
	`title` text NOT NULL,
	`published_label` text NOT NULL,
	`read_time` text NOT NULL,
	`panels_json` text DEFAULT '[]' NOT NULL,
	`publication_status` text DEFAULT 'draft' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`published_at` integer,
	FOREIGN KEY (`series_slug`) REFERENCES `content_series`(`slug`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `content_episodes_series_slug_unique` ON `content_episodes` (`series_slug`,`slug`);--> statement-breakpoint
CREATE UNIQUE INDEX `content_episodes_series_number_unique` ON `content_episodes` (`series_slug`,`number`);--> statement-breakpoint
CREATE TABLE `content_series` (
	`slug` text PRIMARY KEY NOT NULL,
	`title` text NOT NULL,
	`eyebrow` text NOT NULL,
	`creator` text NOT NULL,
	`description` text NOT NULL,
	`long_description` text NOT NULL,
	`story_status` text DEFAULT 'ongoing' NOT NULL,
	`genres_json` text DEFAULT '[]' NOT NULL,
	`tone` text DEFAULT 'coral' NOT NULL,
	`updated_label` text DEFAULT 'Taslak' NOT NULL,
	`rating` real DEFAULT 0 NOT NULL,
	`followers` text DEFAULT 'Yeni' NOT NULL,
	`is_new` integer DEFAULT true NOT NULL,
	`cover_image` text,
	`cover_position` text,
	`publication_status` text DEFAULT 'draft' NOT NULL,
	`is_featured` integer DEFAULT false NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`published_at` integer
);

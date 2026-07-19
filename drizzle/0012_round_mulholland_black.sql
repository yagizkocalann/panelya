ALTER TABLE `content_series` ADD `search_text` text DEFAULT '' NOT NULL;--> statement-breakpoint
CREATE INDEX `content_series_discovery_updated_idx` ON `content_series` (`publication_status`,`story_status`,`updated_at`,`slug`);--> statement-breakpoint
CREATE INDEX `content_series_discovery_rating_idx` ON `content_series` (`publication_status`,`story_status`,`rating`,`slug`);--> statement-breakpoint
CREATE INDEX `content_series_discovery_title_idx` ON `content_series` (`publication_status`,`story_status`,`title`,`slug`);
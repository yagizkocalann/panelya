CREATE TABLE `provider_identities` (
	`provider` text NOT NULL,
	`issuer` text NOT NULL,
	`subject_hash` text NOT NULL,
	`user_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`last_login_at` integer NOT NULL,
	PRIMARY KEY(`provider`, `issuer`, `subject_hash`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `provider_identities_user_provider_unique` ON `provider_identities` (`user_id`,`provider`,`issuer`);--> statement-breakpoint
CREATE INDEX `provider_identities_user_idx` ON `provider_identities` (`user_id`);
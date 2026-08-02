CREATE INDEX `account_tokens_expiry_idx` ON `account_tokens` (`expires_at`);--> statement-breakpoint
CREATE INDEX `rate_limit_buckets_reset_idx` ON `rate_limit_buckets` (`reset_at`);
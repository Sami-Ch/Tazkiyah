SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE INDEX "allocations_donation" ON "app"."allocations" USING btree ("institute_id","donation_id");--> statement-breakpoint
CREATE INDEX "allocations_created_by" ON "app"."allocations" USING btree ("institute_id","created_by");--> statement-breakpoint
CREATE INDEX "causes_cover_media" ON "app"."causes" USING btree ("institute_id","cover_media_id");--> statement-breakpoint
CREATE INDEX "donations_cause" ON "app"."donations" USING btree ("institute_id","cause_id");--> statement-breakpoint
CREATE INDEX "donations_recorded_by" ON "app"."donations" USING btree ("institute_id","recorded_by");--> statement-breakpoint
CREATE INDEX "institute_settings_principal_user" ON "app"."institute_settings" USING btree ("institute_id","principal_user_id");--> statement-breakpoint
CREATE INDEX "institute_settings_updated_by" ON "app"."institute_settings" USING btree ("institute_id","updated_by");--> statement-breakpoint
CREATE INDEX "institute_settings_logo_media" ON "app"."institute_settings" USING btree ("institute_id","logo_media_id");--> statement-breakpoint
CREATE INDEX "receipt_email_jobs_donor" ON "app"."receipt_email_jobs" USING btree ("institute_id","donor_id");--> statement-breakpoint
CREATE INDEX "receipt_email_jobs_trail_link" ON "app"."receipt_email_jobs" USING btree ("institute_id","trail_link_id");--> statement-breakpoint
CREATE INDEX "trail_events_cause" ON "app"."trail_events" USING btree ("institute_id","cause_id");--> statement-breakpoint
CREATE INDEX "trail_events_recorded_by" ON "app"."trail_events" USING btree ("institute_id","recorded_by");--> statement-breakpoint
CREATE INDEX "trail_links_donor" ON "app"."trail_links" USING btree ("institute_id","donor_id");--> statement-breakpoint
CREATE INDEX "trail_links_created_by" ON "app"."trail_links" USING btree ("institute_id","created_by");--> statement-breakpoint
CREATE INDEX "trail_links_revoked_by" ON "app"."trail_links" USING btree ("institute_id","revoked_by");--> statement-breakpoint
CREATE INDEX "users_email_lookup" ON "app"."users" USING btree ("institute_id","email");--> statement-breakpoint
CREATE INDEX "users_username_lookup" ON "app"."users" USING btree ("institute_id","username");
--> statement-breakpoint
RESET ROLE;

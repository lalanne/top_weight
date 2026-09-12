# Supabase setup for Top Weight cloud sync

One-time steps to stand up the backend. The app code assumes these are done.

1. **Create a project** at [supabase.com](https://supabase.com) (the free tier is enough for a family's workout data).
2. **Run the schema.** Open the project's SQL Editor, paste the contents of `schema.sql` in this folder, and run it. It creates the `profiles`, `exercises`, and `workout_records` tables, Row Level Security policies, the cascade-tombstone triggers, the three last-write-wins upsert functions, and `delete_own_account()` (needed for in-app account deletion, an App Store review requirement — see below). The script is safe to re-run, including if you already ran an earlier version of it — just paste the current file's contents again and run it to pick up new functions like this one.
3. **Disable email confirmation** (per product decision — register and sign in immediately, no confirmation email): in the dashboard go to **Authentication → Providers → Email**, turn off **Confirm email**, save.
4. **Copy your credentials**: in **Project Settings → API**, copy the **Project URL** and the **anon/public key** (not the service role key — that one must never ship in the app). Put them into `TopWeight/Services/SupabaseConfig.swift` (see the placeholders left in that file) or wherever the app's config step ends up pointing.

The anon key is meant to be embedded in client apps — Row Level Security on the tables is the actual security boundary, not secrecy of this key.

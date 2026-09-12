import Foundation

/// Fill these in after creating your Supabase project — see supabase/README.md.
/// The anon key is meant to be embedded in client apps; Row Level Security on
/// the tables (see supabase/schema.sql) is the actual security boundary.
enum SupabaseConfig {
    static let url = URL(string: "https://awfvipjqhtjsbvcrmarl.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3ZnZpcGpxaHRqc2J2Y3JtYXJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyMzM2MzgsImV4cCI6MjA5OTgwOTYzOH0.WzeETT4XAqgGmvxy3Iv5RXFWhW2T_qoC1B6Fv570mMQ"
}

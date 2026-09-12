import Foundation
import Supabase

/// Owns the Supabase client and the account's live sign-in state.
/// An account is optional in this app — `RootView` never gates on it,
/// it only unlocks the cloud-backup features in `UserManagerSheet`.
@MainActor
@Observable
final class AuthService {
    private(set) var session: Session?

    let client: SupabaseClient

    init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
        session = client.auth.currentSession
        Task { [weak self] in
            await self?.observeAuthState()
        }
    }

    var isAuthenticated: Bool { session != nil }

    private func observeAuthState() async {
        for await (_, newSession) in client.auth.authStateChanges {
            session = newSession
        }
    }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Permanently deletes the account and every row it owns (via the `owner_id`
    /// cascade in supabase/schema.sql), then signs out locally. Required for App
    /// Store review — apps that support account creation must support in-app deletion.
    /// Data already synced to this device is left alone; the account just stops syncing.
    func deleteAccount() async throws {
        try await client.rpc("delete_own_account").execute()
        try await client.auth.signOut()
    }
}

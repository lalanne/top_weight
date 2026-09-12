import SwiftUI

struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(SyncService.self) private var syncService

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private enum Mode {
        case signIn, register
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session = authService.session {
                    signedInView(email: session.user.email ?? "—")
                } else {
                    authForm
                }
            }
            .navigationTitle("Cloud Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This permanently deletes your cloud account and everything backed up to it. Workouts already stored on this phone are not affected.")
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await authService.deleteAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var authForm: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.signIn)
                    Text("Create Account").tag(Mode.register)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(mode == .register ? .newPassword : .password)
            } footer: {
                if mode == .register {
                    Text("Backs up profiles, exercises, and workouts to the cloud. Any workouts already stored on this phone will be uploaded too.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(mode == .signIn ? "Sign In" : "Create Account")
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmit || isSubmitting)
            }
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if mode == .signIn {
                try await authService.signIn(email: email, password: password)
            } else {
                try await authService.signUp(email: email, password: password)
            }
            await syncService.performInitialSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signedInView(email: String) -> some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in")
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let lastSyncedAt = syncService.lastSyncedAt {
                    LabeledContent("Last synced", value: lastSyncedAt.formatted(date: .abbreviated, time: .shortened))
                }
                switch syncService.syncStatus {
                case .syncing:
                    LabeledContent("Status") {
                        ProgressView()
                    }
                case .error(let message):
                    LabeledContent("Status", value: "Couldn't sync")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .idle:
                    EmptyView()
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authService.signOut()
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete Account")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Permanently deletes your cloud account and its backed-up data. Workouts already on this phone stay put.")
            }
        }
    }
}

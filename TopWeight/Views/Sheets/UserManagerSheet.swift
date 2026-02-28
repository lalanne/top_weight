import SwiftUI
import SwiftData

struct UserManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \User.createdAt, order: .reverse) private var users: [User]

    @State private var newUserName = ""
    @State private var userToEdit: User?
    @State private var showAddError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("User name", text: $newUserName)
                        Button("Add") {
                            addUser()
                        }
                        .disabled(newUserName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Add new user")
                }

                Section {
                    ForEach(users, id: \.id) { user in
                        Button {
                            userToEdit = user
                        } label: {
                            Text(user.name)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(user)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                userToEdit = user
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                } header: {
                    Text("Users")
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $userToEdit) { user in
                EditUserSheet(user: user) {
                    userToEdit = nil
                }
            }
            .alert("Could not add user", isPresented: $showAddError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Something went wrong. Please try again.")
            }
        }
    }

    private func addUser() {
        let name = newUserName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let user = User(name: name)
        modelContext.insert(user)

        do {
            try modelContext.save()
            newUserName = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            showAddError = true
        }
    }
}

struct EditUserSheet: View {
    @Environment(\.modelContext) private var modelContext
    let user: User
    @State private var name: String
    let onDismiss: () -> Void

    init(user: User, onDismiss: @escaping () -> Void) {
        self.user = user
        self._name = State(initialValue: user.name)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("User name", text: $name)
            }
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        user.name = trimmed
                        try? modelContext.save()
                        onDismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

extension User: Identifiable {}

#Preview {
    UserManagerSheet()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}

import SwiftUI
import SwiftData

struct UserManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \User.createdAt, order: .reverse) private var users: [User]

    @State private var newUserName = ""
    @State private var newUserPhotoData: Data?
    @State private var newUserAvatarSymbol: String?
    @State private var userToEdit: User?
    @State private var showAddError = false
    @State private var showAddPhotoSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        if let data = newUserPhotoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else if let symbol = newUserAvatarSymbol {
                            Image(systemName: symbol)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.secondary.opacity(0.2), in: Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                        }
                        TextField("User name", text: $newUserName)
                    }
                    Button("Add photo or avatar") {
                        showAddPhotoSheet = true
                    }
                    .foregroundStyle(Color.accentColor)
                    HStack {
                        Spacer()
                        Button("Add") {
                            addUser()
                        }
                        .disabled(newUserName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Text("Add new user")
                }

                Section {
                    ForEach(users, id: \.id) { user in
                        Button {
                            userToEdit = user
                        } label: {
                            HStack(spacing: 12) {
                                UserAvatarView(user: user, size: 36)
                                Text(user.name)
                            }
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
            .sheet(isPresented: $showAddPhotoSheet) {
                NavigationStack {
                    AvatarPickerView(
                        selectedSymbol: $newUserAvatarSymbol,
                        onPhotoPicked: { data in
                            newUserPhotoData = data
                            newUserAvatarSymbol = nil
                        }
                    )
                    .padding()
                    .navigationTitle("Photo or avatar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showAddPhotoSheet = false
                            }
                        }
                    }
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

        let user = User(
            name: name,
            photoData: newUserPhotoData,
            avatarSymbol: newUserAvatarSymbol
        )
        modelContext.insert(user)

        do {
            try modelContext.save()
            newUserName = ""
            newUserPhotoData = nil
            newUserAvatarSymbol = nil
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
    @State private var selectedAvatarSymbol: String?
    let onDismiss: () -> Void

    init(user: User, onDismiss: @escaping () -> Void) {
        self.user = user
        self._name = State(initialValue: user.name)
        self._selectedAvatarSymbol = State(initialValue: user.avatarSymbol)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        UserAvatarView(user: user, size: 64)
                        TextField("User name", text: $name)
                    }
                }
                Section {
                    AvatarPickerView(
                        selectedSymbol: $selectedAvatarSymbol,
                        onPhotoPicked: { data in
                            user.photoData = data
                            user.avatarSymbol = nil
                            selectedAvatarSymbol = nil
                        }
                    )
                }
                if user.photoData != nil || user.avatarSymbol != nil {
                    Section {
                        Button("Remove photo", role: .destructive) {
                            user.photoData = nil
                            user.avatarSymbol = nil
                            selectedAvatarSymbol = nil
                        }
                    }
                }
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
                        user.avatarSymbol = selectedAvatarSymbol
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

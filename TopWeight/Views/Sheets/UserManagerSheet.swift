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
    @State private var userToDelete: User?
    @State private var showAddError = false
    @State private var showAddPhotoSheet = false
    @State private var showDeleteConfirmation = false

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
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                userToDelete = user
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                userToEdit = user
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        .contextMenu {
                            Button {
                                userToEdit = user
                            } label: {
                                Label("Edit profile", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                userToDelete = user
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete user", systemImage: "trash")
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
            .alert("Delete user?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    userToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let user = userToDelete {
                        modelContext.delete(user)
                        try? modelContext.save()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    userToDelete = nil
                }
            } message: {
                if let user = userToDelete {
                    Text("Delete \(user.name)? This will also remove all their workout records.")
                }
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
    @State private var showDeleteUserConfirmation = false
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
                Section {
                    Button("Delete user", role: .destructive) {
                        showDeleteUserConfirmation = true
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
                        if selectedAvatarSymbol != nil {
                            user.photoData = nil
                        }
                        try? modelContext.save()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedAvatarSymbol) { _, newValue in
                if newValue != nil {
                    user.photoData = nil
                }
            }
            .alert("Delete user?", isPresented: $showDeleteUserConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    modelContext.delete(user)
                    try? modelContext.save()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }
            } message: {
                Text("Delete \(user.name)? This will also remove all their workout records.")
            }
        }
    }
}

extension User: Identifiable {}

#Preview {
    UserManagerSheet()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}

import SwiftUI

/// Preset SF Symbol avatars for users.
enum PresetAvatar: String, CaseIterable {
    case personFill = "person.fill"
    case personCircle = "person.circle.fill"
    case figureRun = "figure.run"
    case figureStrength = "figure.strengthtraining.traditional"
    case dumbbell = "dumbbell.fill"
    case heart = "heart.fill"
    case star = "star.fill"
    case bolt = "bolt.fill"
    case flame = "flame.fill"
    case trophy = "trophy.fill"

    var symbolName: String { rawValue }
}

struct AvatarPickerView: View {
    @Binding var selectedSymbol: String?
    let onPhotoPicked: (Data) -> Void
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile photo")
                .font(.headline)

            HStack(spacing: 16) {
                photoButtons
                Spacer()
            }

            Text("Or choose an avatar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(PresetAvatar.allCases, id: \.rawValue) { avatar in
                    Button {
                        selectedSymbol = avatar.symbolName
                    } label: {
                        Image(systemName: avatar.symbolName)
                            .font(.title2)
                            .foregroundStyle(selectedSymbol == avatar.symbolName ? .white : .primary)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedSymbol == avatar.symbolName ? Color.accentColor : Color.secondary.opacity(0.2),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSource) { data in
                onPhotoPicked(data)
                selectedSymbol = nil
            }
        }
    }

    private var photoButtons: some View {
        Group {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    imagePickerSource = .camera
                    showImagePicker = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                }
            }
            Button {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            } label: {
                Label("Choose photo", systemImage: "photo.on.rectangle")
            }
        }
    }
}

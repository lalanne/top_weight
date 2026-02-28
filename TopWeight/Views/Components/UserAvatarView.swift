import SwiftUI

struct UserAvatarView: View {
    let user: User
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let data = user.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let symbol = user.avatarSymbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Color.secondary.opacity(0.2), in: Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

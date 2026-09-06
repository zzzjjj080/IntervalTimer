import SwiftUI

struct PhoneRootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("区切りタイマー")
                .font(.largeTitle.bold())
            Text("いま組み立て中です。")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

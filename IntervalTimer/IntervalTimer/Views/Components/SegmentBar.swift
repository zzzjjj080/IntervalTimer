import SwiftUI

/// 区切りぶんの帯。消化済み／進行中／未消化を塗り分ける。
struct SegmentBar: View {
    let parts: Int
    /// 進行中の区切り（0始まり）。
    let index: Int
    let skin: Skin
    /// 終了後は全部を消化済みにする。
    var allDone: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(1, parts), id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(height: 5)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
    }

    private func color(for i: Int) -> Color {
        if allDone || i < index { return skin.ink }
        if i == index { return skin.ink.opacity(0.55) }
        return skin.faint
    }
}

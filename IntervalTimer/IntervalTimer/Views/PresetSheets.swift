import SwiftUI
import IntervalTimerCore

/// いまの設定に名前を付けて保存する。
struct SavePresetSheet: View {
    let config: TimerConfig
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("\(config.minutes)分 / \(config.parts)区切り")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Skin.normal.ink)

                TextField("名前", text: $name)
                    .frame(minHeight: 44)

                Button {
                    onSave(name)
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Skin.normal.background)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Skin.normal.ink)
                        )
                }
                .buttonStyle(.plain)

                Button("やめる") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Skin.normal.inkDim)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 4)
        }
        .background(Skin.normal.background.ignoresSafeArea())
    }
}

/// プリセットを消す画面。
///
/// 読み込む行のとなりに「✕」を置くと必ず誤爆するので、消す操作はここへ分けてある。
/// 何が消えるのかを名前と数字の両方で出す。
struct EditPresetsSheet: View {
    @State var book: PresetBook
    let onChange: (PresetBook) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: Preset?

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let target = pendingDelete {
                    confirm(target)
                } else {
                    list
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Skin.normal.background.ignoresSafeArea())
    }

    private var list: some View {
        VStack(spacing: 6) {
            ForEach(book.presets) { preset in
                Button {
                    pendingDelete = preset
                } label: {
                    HStack {
                        Text(preset.displayName)
                            .font(.system(size: 14))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Skin.normal.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Skin.normal.ink.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            Button("閉じる") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Skin.normal.inkDim)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func confirm(_ target: Preset) -> some View {
        VStack(spacing: 8) {
            Text("「\(target.displayName)」を消します")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Skin.normal.ink)
                .multilineTextAlignment(.center)
            Text("\(target.config.minutes)分 / \(target.config.parts)区切り")
                .font(.system(size: 12))
                .foregroundStyle(Skin.normal.inkDim)

            Button {
                // 消えたIDへの操作は無視されるので、二重に押しても落ちない。
                book.remove(id: target.id)
                onChange(book)
                pendingDelete = nil
                if book.presets.isEmpty { dismiss() }
            } label: {
                Text("消す")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Skin.done.background)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: PaletteHex.warnBackground))
                    )
            }
            .buttonStyle(.plain)

            Button("やめる") { pendingDelete = nil }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Skin.normal.inkDim)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

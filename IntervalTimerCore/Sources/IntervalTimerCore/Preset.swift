import Foundation

/// 保存した設定。3枠まで。
///
/// 並べ替え・削除・書き換えは、名前ではなく必ず `id` で指す。
/// 名前で突き合わせると、同じ名前を2つ作った瞬間に別の枠を書き換えてしまう。
public struct Preset: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var config: TimerConfig

    public init(id: UUID = UUID(), name: String, config: TimerConfig) {
        self.id = id
        self.name = name
        self.config = config
    }

    /// 名前が空のときに画面へ出す代わりの文字。
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(config.minutes)分 / \(config.parts)" : trimmed
    }
}

/// プリセット3枠ぶんの入れ物。`@AppStorage` へJSONで入れる。
///
/// 項目を足したときに、既に保存されている古いJSONが読めなくなると
/// **保存済みのプリセットが丸ごと消える。** 足りない項目は既定値で埋めて必ず読めるようにする。
public struct PresetBook: Equatable, Codable, Sendable {
    public static let capacity = 3

    public private(set) var presets: [Preset]

    public init(presets: [Preset] = []) {
        self.presets = Array(presets.prefix(Self.capacity))
    }

    public var isFull: Bool { presets.count >= Self.capacity }

    /// 空きがあれば足す。いっぱいなら何もしない（黙って古いものを消さない）。
    public mutating func add(_ preset: Preset) {
        guard !isFull else { return }
        presets.append(preset)
    }

    /// 見つからないIDへの操作は黙って無視する。取りこぼしても落ちないように。
    public mutating func remove(id: Preset.ID) {
        presets.removeAll { $0.id == id }
    }

    public mutating func rename(id: Preset.ID, to name: String) {
        guard let i = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[i].name = name
    }

    public func preset(id: Preset.ID) -> Preset? {
        presets.first { $0.id == id }
    }

    // MARK: - 保存と読み出し

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decodeIfPresent([Preset].self, forKey: .presets) ?? []
        self.presets = Array(raw.prefix(Self.capacity))
    }

    public func encodedJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// 壊れたJSONでも落ちず、空の状態で始まる。
    public static func decode(json: String) -> PresetBook {
        guard let data = json.data(using: .utf8),
              let book = try? JSONDecoder().decode(PresetBook.self, from: data) else {
            return PresetBook()
        }
        return book
    }
}

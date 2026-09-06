import UIKit
import IntervalTimerCore

/// iPhone の触覚。**Watch とは作りが違う。**
///
/// watchOS は種類と回数でしか強さを作れないが、iOS には `intensity` がある。
/// ただし**指定しないと端末側の判断で弱まり、初回は遅れて鳴る**ので、
/// `prepare()` と `intensity` を必ず明示する（引き継ぎ書 4-29）。
///
/// | 場面 | 触覚 |
/// |---|---|
/// | ＋ − を押した | `.soft`（軽く。何十回も押すので） |
/// | 開始 | `.heavy` |
/// | 区切りの75% / 区切りが0 | `.warning` を2回 |
/// | 全体が0 | `.success` → 間 → `.heavy` を3回 |
@MainActor
final class PhoneHaptics {

    private let impact = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notice = UINotificationFeedbackGenerator()
    private var running: Task<Void, Never>?

    init() { warmUp() }

    /// 直前に用意しておかないと1発目が鳴らない。
    func warmUp() {
        impact.prepare(); heavy.prepare(); soft.prepare(); notice.prepare()
    }

    func step() {
        soft.impactOccurred(intensity: 0.7)
        soft.prepare()
    }

    func start() {
        running?.cancel()
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }

    func play(_ event: TimerEvent) {
        running?.cancel()
        switch event {
        case .warning, .splitEnded:
            running = Task { @MainActor in
                for i in 0..<2 {
                    guard !Task.isCancelled else { return }
                    notice.notificationOccurred(.warning)
                    notice.prepare()
                    if i == 0 { try? await Task.sleep(for: .milliseconds(220)) }
                }
            }
        case .finished:
            running = Task { @MainActor in
                notice.notificationOccurred(.success)
                try? await Task.sleep(for: .milliseconds(300))
                for _ in 0..<3 {
                    guard !Task.isCancelled else { return }
                    heavy.impactOccurred(intensity: 1.0)
                    heavy.prepare()
                    try? await Task.sleep(for: .milliseconds(160))
                }
            }
        }
    }
}

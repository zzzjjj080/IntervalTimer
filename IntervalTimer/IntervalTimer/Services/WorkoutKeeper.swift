import Foundation
import HealthKit

/// 画面を消してもアプリを動かし続けるための入れ物。
///
/// 練習中は腕を下ろすし、他のアプリも触る。何もしないと watchOS はアプリを止めるので、
/// タイマーとして使い物にならなくなる。`HKWorkoutSession` が `.running` の間は
/// フォアグラウンド相当の扱いになり、実行も触覚も続く。実際に運動している場面なので用途としても正当。
///
/// **予備の手段は持たない**（2026-09-13 決定）。`WKExtendedRuntimeSession`（self-care）を試したが、
/// 上限が10分で練習の長さに足りず、実機では30秒ほどで文字盤に戻った。野球のタイマーが
/// self-care を宣言する理由も審査で説明しにくい。ヘルスケアを断った人には、許可を画面で案内する。
///
/// **失敗は握り潰さない。** 無反応が一番たちが悪いので、
/// 起きたことは全部 ``errors`` に積んで画面から見えるようにしている。
@MainActor
@Observable
final class WorkoutKeeper: NSObject {

    enum Mode: Equatable {
        /// ワークアウトとして動いている。画面を消しても止まらない。
        case workout
        /// 何も確保できていない。画面を消すと止まる。
        case none

        var keepsRunningInBackground: Bool { self == .workout }
    }

    private(set) var mode: Mode = .none

    /// **ヘルスケアで断られている。** このときだけ、画面で「許可すると動き続ける」と案内する。
    /// 端末が対応していない・一時的な失敗とは分けて持つ（案内しても直らないため）。
    private(set) var needsHealthPermission = false

    /// 状態が変わったときに呼ぶ。**始めた直後だけでなく、途中で止められたときも**
    /// 画面の注意書きを出し直すために要る。
    var onChange: (@MainActor () -> Void)?

    /// 起きたことを全部ためる。**最初の1件がいちばん本当の原因に近い**ので、上書きしない。
    private(set) var errors: [String] = []
    var firstError: String? { errors.first }

    #if DEBUG
    /// いま握っているセッションの状態を1行で。足あとに添えて、戻された瞬間の様子を残す。
    /// 1=notStarted 2=running 3=ended 4=paused 5=prepared 6=stopped
    var stateText: String {
        let w = session.map { String($0.state.rawValue) } ?? "-"
        return "mode=\(mode) W=\(w)"
    }
    #endif

    private let store = HKHealthStore()
    /// 自分で終わらせている最中かどうか。
    /// `session.end()` を呼ぶと `didChangeTo .ended` が飛んでくるので、
    /// これが無いと「外から止められました」という嘘のエラーを出してしまう。
    private var isEnding = false
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
    }
    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
    }

    // MARK: - 開始

    /// 実機の様子を `devicectl ... --console` で読むための記録。DEBUG限定。
    private func log(_ message: String) {
        #if DEBUG
        print("[WorkoutKeeper] \(message)")
        Trail.shared.add(message)
        #endif
    }

    func start() async {
        errors.removeAll()
        needsHealthPermission = false
        isEnding = false
        mode = .none
        log("start(): ヘルスケアが使えるか = \(HKHealthStore.isHealthDataAvailable())")

        guard HKHealthStore.isHealthDataAvailable() else {
            errors.append(String(localized: "この端末ではヘルスケアが使えません。"))
            return
        }

        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            log("requestAuthorization: 通った")
        } catch {
            log("requestAuthorization: 失敗 \(error)")
            errors.append(String(localized: "ヘルスケアの許可を確認できませんでした: \(error.localizedDescription)"))
            return
        }

        // requestAuthorization は「拒否された」場合も成功で返る。状態を別に見る必要がある。
        // 一度断られると、二度と許可のダイアログは出ない。設定から変えてもらうしかない。
        let st = store.authorizationStatus(for: HKObjectType.workoutType())
        log("workoutType の状態 = \(st.rawValue)  (0=未定 1=拒否 2=許可)")
        guard st == .sharingAuthorized else {
            needsHealthPermission = true
            errors.append(String(localized: "ワークアウトの保存が許可されていません。"))
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .baseball
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self

            let now = Date()
            session.startActivity(with: now)
            try await builder.beginCollection(at: now)

            self.session = session
            self.builder = builder
            self.mode = .workout
            log("ワークアウトを開始した。state = \(session.state.rawValue) (1=notStarted 2=running)")
        } catch {
            log("ワークアウトの開始で例外: \(error)")
            errors.append(String(localized: "ワークアウトを開始できませんでした: \(error.localizedDescription)"))
        }
    }

    // MARK: - 終了

    /// タイマーが終わった／リセットされたときに呼ぶ。
    /// ワークアウトは**保存する**。動かしっぱなしで捨てると、目的外の使い方に見えてしまう。
    func end() async {
        isEnding = true
        if let session, let builder {
            let now = Date()
            session.end()
            do {
                try await builder.endCollection(at: now)
                _ = try await builder.finishWorkout()
            } catch {
                errors.append(String(localized: "ワークアウトの保存に失敗しました: \(error.localizedDescription)"))
            }
        }
        session = nil
        builder = nil
        mode = .none
        isEnding = false
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutKeeper: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in self.log("状態が変わった: \(fromState.rawValue) → \(toState.rawValue)") }
        guard toState == .stopped || toState == .ended else { return }
        Task { @MainActor in
            // 自分で終わらせているなら、これは想定どおりの通知。エラーにしない。
            guard !self.isEnding else { return }
            if self.mode == .workout, self.session != nil {
                self.errors.append(String(localized: "ワークアウトが外から止められました。画面を消すと計測が止まります。"))
                self.mode = .none
                self.onChange?()
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            self.errors.append(String(localized: "ワークアウトが止まりました: \(error.localizedDescription)"))
            self.mode = .none
            self.onChange?()
        }
    }
}

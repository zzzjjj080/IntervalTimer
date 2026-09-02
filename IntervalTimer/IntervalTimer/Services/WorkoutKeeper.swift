import Foundation
import HealthKit
import WatchKit

/// 画面を消してもアプリを動かし続けるための入れ物。
///
/// 練習中は腕を下ろすし、他のアプリも触る。何もしないと watchOS はアプリを止めるので、
/// タイマーとして使い物にならなくなる。`HKWorkoutSession` が `.running` の間は
/// フォアグラウンド相当の扱いになり、実行も触覚も続く。実際に運動している場面なので用途としても正当。
///
/// 許可が取れなかったときは ``WKExtendedRuntimeSession`` へ落ちる。
/// こちらは連続動作の時間に上限があるので、その旨を画面に出す。
///
/// **失敗は握り潰さない。** 無反応が一番たちが悪いので、
/// 起きたことは全部 ``errors`` に積んで画面から見えるようにしている。
@MainActor
@Observable
final class WorkoutKeeper: NSObject {

    enum Mode: Equatable {
        /// ワークアウトとして動いている。いちばん確実。
        case workout
        /// 予備の手段。連続動作の時間に上限がある。
        case extended
        /// 何も確保できていない。画面を消すと止まる。
        case none

        var keepsRunningInBackground: Bool { self != .none }
    }

    private(set) var mode: Mode = .none

    /// 起きたことを全部ためる。**最初の1件がいちばん本当の原因に近い**ので、上書きしない。
    private(set) var errors: [String] = []
    var firstError: String? { errors.first }

    private let store = HKHealthStore()
    /// 自分で終わらせている最中かどうか。
    /// `session.end()` を呼ぶと `didChangeTo .ended` が飛んでくるので、
    /// これが無いと「外から止められました」という嘘のエラーを出してしまう。
    private var isEnding = false
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var extended: WKExtendedRuntimeSession?

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
    }
    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
    }

    // MARK: - 開始

    func start() async {
        errors.removeAll()
        isEnding = false

        guard HKHealthStore.isHealthDataAvailable() else {
            errors.append("この端末ではヘルスケアが使えません。")
            startExtendedSession()
            return
        }

        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            errors.append("ヘルスケアの許可を確認できませんでした: \(error.localizedDescription)")
            startExtendedSession()
            return
        }

        // requestAuthorization は「拒否された」場合も成功で返る。状態を別に見る必要がある。
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            errors.append("ワークアウトの保存が許可されていません。")
            startExtendedSession()
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
        } catch {
            errors.append("ワークアウトを開始できませんでした: \(error.localizedDescription)")
            startExtendedSession()
        }
    }

    private func startExtendedSession() {
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        extended = s
        mode = .extended
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
                errors.append("ワークアウトの保存に失敗しました: \(error.localizedDescription)")
            }
        }
        session = nil
        builder = nil

        extended?.invalidate()
        extended = nil

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
        guard toState == .stopped || toState == .ended else { return }
        Task { @MainActor in
            // 自分で終わらせているなら、これは想定どおりの通知。エラーにしない。
            guard !self.isEnding else { return }
            if self.mode == .workout, self.session != nil {
                self.errors.append("ワークアウトが外から止められました。画面を消すと計測が止まります。")
                self.mode = .none
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            self.errors.append("ワークアウトが止まりました: \(error.localizedDescription)")
            self.mode = .none
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WorkoutKeeper: WKExtendedRuntimeSessionDelegate {

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.errors.append("まもなく時間切れです。画面を点けたままにしてください。")
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                self.errors.append("予備の手段も使えませんでした: \(error.localizedDescription)")
            }
            if self.mode == .extended { self.mode = .none }
        }
    }
}

import SwiftUI
import IntervalTimerCore

/// 設定画面のいちばん下に置く、控えめな1行。
///
/// 共通実装（`~/Claude/shared/TipJar/CoffeeTipSection.swift`）は `Form` / `List` 前提で、
/// この画面は `ScrollView` + `VStack` に自前の配色なので、見た目だけ書き下ろしている。
/// **購入処理は共通の ``TipJar`` をそのまま使う。**
///
/// 触ってはいけないところ:
/// - 金額を決め打ちしない。`displayPrice` をそのまま出す（国で通貨も金額も変わる）
/// - 「寄付」「Donation」「カンパ」と書かない。開発者へのチップと慈善寄付は扱いが別
/// - 杯数は復元されない。消耗型なので機種変更で0に戻る。だから「この端末で」と書く
struct CoffeeTip: View {
    @Bindable var tipJar: TipJar

    var body: some View {
        VStack(spacing: 4) {
            switch tipJar.state {
            case .thanks:
                Text("ありがとうございます")
                    .foregroundStyle(Color(hex: PaletteHex.tipInk))
                closeButton
            case .failed(let message):
                Text(message)
                    .foregroundStyle(Color(hex: PaletteHex.tipInk))
                    .multilineTextAlignment(.center)
                closeButton
            case .unavailable where !isDemo:
                // 製品が取れないときは黙って消える。設定画面に用は無い
                EmptyView()
            default:
                buyButton
                gratitude
            }
        }
        .font(.system(size: 12))
        .padding(.top, 10)
        .task { await tipJar.load() }
        // 購入が通った瞬間だけ鳴らす。承認待ちが後から届く場合もここを通る
        .sensoryFeedback(.success, trigger: tipJar.cups)
    }

    private var buyButton: some View {
        Button {
            Task { await tipJar.tip() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "cup.and.saucer.fill")
                Text("コーヒーを奢る")
                if let price = tipJar.displayPrice ?? demoPrice {
                    Text(price).fontWeight(.semibold)
                }
            }
            .foregroundStyle(Color(hex: PaletteHex.tipInk))
            .frame(maxWidth: .infinity, minHeight: 44)
            // Spacer や余白は描画を持たないので、これが無いと端を押しても反応しない
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isDemo && (tipJar.product == nil || tipJar.state == .purchasing))
        .accessibilityIdentifier("buyCoffee")
    }

    /// 見た目だけ確かめるための入口。
    ///
    /// StoreKit の設定は Xcode が起動時に差し込むもので、`simctl launch` では効かない。
    /// つまりシミュレータからは、この行が一度も出せない。並びだけは見ておきたいので、
    /// DEBUG限定で値段を偽って描かせる。**購入は動かない。**
    private var isDemo: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["IT_TIP_DEMO"] == "1"
        #else
        return false
        #endif
    }

    private var demoPrice: String? { isDemo ? "¥200" : nil }

    private var closeButton: some View {
        Button("閉じる") { tipJar.dismissThanks() }
            .buttonStyle(.plain)
            .foregroundStyle(Skin.normal.inkDim)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    /// 奢ってくれた人にだけ出すお礼。
    /// 機種変更すると0に戻ってこの行は消えるので、消えても嘘にならない書き方にしてある。
    @ViewBuilder
    private var gratitude: some View {
        switch tipJar.cups {
        case 0:
            EmptyView()
        case 1:
            Text("奢ってくれてありがとうございました")
                .font(.system(size: 11))
                .foregroundStyle(Skin.normal.inkDim)
        default:
            Text("この端末で \(tipJar.cups) 回も奢ってくれてありがとうございました")
                .font(.system(size: 11))
                .foregroundStyle(Skin.normal.inkDim)
                .multilineTextAlignment(.center)
        }
    }
}

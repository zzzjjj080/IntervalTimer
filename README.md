# インターバル（watchOS）

野球の練習で使う、Apple Watch 単体で動くインターバルタイマー。
全体時間と分割回数を入れると、**全体の残り時間と、いまの区切りの残り時間を同時に**出す。

- 対象: Apple Watch Series 11 / watchOS 11.0 以降
- 構成: watchOS 単体アプリ（iPhone コンパニオンなし）
- バンドルID: `com.zzzjjj080.IntervalTimer`

## 中身

```
IntervalTimerCore/          UIに依存しないロジック。Xcodeを開かずに swift test で回せる
  TimerConfig.swift         全体秒数・分割数・区切りの境界
  TimerEngine.swift         経過の算出・区切りの判定・状態遷移
  TimeText.swift            秒 → 文字（切り上げ）
  Preset.swift              保存した設定 3枠
  Palette.swift             色の数値とコントラスト比
IntervalTimer/              watchOS アプリ
  Info.plist                同期グループの外に置く（中に置くとビルドが必ず落ちる）
  IntervalTimer/
    Models/Runner.swift     画面とエンジンをつなぐ
    Services/               ハプティクス、HKWorkoutSession
    Views/                  設定・実行・終了
      Components/SegmentRing.swift  区切りぶんに分かれた円環
prototype/index.html        挙動を決めたHTMLプロトタイプ
SPEC.md                     実装仕様
```

## 時間の測り方（ここが要）

`Timer` で1秒ずつ減算していない。経過は常に
**「現在時刻 − 仮想の開始時刻」** で出す。画面が消えてもアプリが止まっても、
次に時刻を渡した瞬間に正しい値へ追いつく。

区切りの境界は `全体秒数 × i / 分割数` で**都度**計算する。
1区切りの秒数を足し込むと、丸め誤差が溜まって最後の区切りが0で終わらない。

秒の数字は `Text(timerInterval:)` に描かせている。システムが描画を維持するので、
常時表示（Always-On）のままでもアプリのコードを動かさずに数字が進む。
そのぶん、**アプリ側の状態は「本当に変わった瞬間」しか動かさない**（区切り・警告・停止だけ）。
区切りの判定とハプティクスは自前の0.1秒ループでやる。

## 画面の作り

実行中は、**区切りぶんに分かれた円環**の中に数字を置く。1本の弧が1区切りで、
消化済みは塗り、進行中は途中まで塗る。数字を読まなくても、
「いま何区切り目か」と「その中でどこまで来たか」が掴める。

円環だけは `TimelineView(.periodic(by: 1))` で1秒ごとに描き直す。
秒の数字はシステムが描いているので、そちらを巻き込まない。
0.1秒ごとにすれば滑らかになるが、1区切り5分なら1秒で弧の1/300しか進まず段は見えない。
**腕に着けて1時間動かすものなので、粗いほうを選んでいる。**

**円環の大きさは `WKInterfaceDevice.screenBounds` から決める。**
`GeometryReader` に測らせると、安全領域の扱いで高さが 157pt にも 210pt にもなり、
そのたびに円環が縮んで数字と重なった。画面の実寸から決めれば、機種が変わっても1か所で効く。
安全領域を外すのは、いちばん外側の1か所だけ（重ねて外すとかえって狭くなる）。

## 背面で動かし続ける

`HKWorkoutSession`（`.baseball` / `.outdoor`）が `.running` の間、
アプリはフォアグラウンド相当の扱いになり、実行も触覚も続く。

- HealthKit のエンタイトルメント（`IntervalTimer.entitlements`）
- `Info.plist` の `WKBackgroundModes` = `workout-processing`
- `Info.plist` の `WKWatchOnly` = `true`（**これが無いとインストールで弾かれる**）

許可が取れなければ `WKExtendedRuntimeSession` へ落ち、その旨を画面に1行出す。
失敗は握り潰さず、理由をそのまま画面に出す。

## 確認

**シミュレータは1台だけ起動する。** 複数起動していると `booted` が別の端末に飛ぶ。
UDIDで名指しするのが確実。

```bash
# ロジック（Xcode不要・速い）
cd IntervalTimerCore && swift test

# シミュレータ
xcrun simctl shutdown all
xcrun simctl boot "Apple Watch Series 11 (46mm)"
cd IntervalTimer && xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData/IntervalTimer-*/Build/Products/Debug-watchsimulator -maxdepth 1 -name IntervalTimer.app)"

# 確認したい画面へ直接入る（DEBUG構成のみ）
#   IT_START="全体分,分割,何秒前に始めたことにするか"
#   IT_PAUSED=1        一時停止した状態で出す
#   IT_SHEET=save|edit|delete   シートを開いた状態で出す
#   IT_NO_WORKOUT=1    ヘルスケアの許可を求めない
W=$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)
SIMCTL_CHILD_IT_NO_WORKOUT=1 SIMCTL_CHILD_IT_START="20,4,250"  xcrun simctl launch "$W" com.zzzjjj080.IntervalTimer   # 警告色
SIMCTL_CHILD_IT_NO_WORKOUT=1 SIMCTL_CHILD_IT_START="20,4,1200" xcrun simctl launch "$W" com.zzzjjj080.IntervalTimer   # 終了画面
SIMCTL_CHILD_IT_NO_WORKOUT=1 SIMCTL_CHILD_IT_SHEET=delete      xcrun simctl launch "$W" com.zzzjjj080.IntervalTimer   # 消す確認

# 保存の確認（アプリの外から値を置いて、起動時に復元されるか見る）
xcrun simctl spawn "$W" defaults write com.zzzjjj080.IntervalTimer lastMinutes -int 12

# 「アプリが裏で止められた」状態の再現
PID=$(xcrun simctl launch "$W" com.zzzjjj080.IntervalTimer | awk '{print $2}')
kill -STOP "$PID"; sleep 30; kill -CONT "$PID"

# リリース構成に確認用の入口が残っていないこと
strings .../Release-watchsimulator/IntervalTimer.app/IntervalTimer | grep IT_START   # 何も出ないこと

# 実機
./install-watch.sh
```

`IT_NO_WORKOUT=1` はヘルスケアの許可ダイアログを出さないための逃げ道。
シミュレータには許可を外から与える手段が無く、合成タップもシステムダイアログには届かない。
**背面動作そのものの確認は実機でやる。**

## 受け入れ基準の状況

仕様書 5節の11項目は `IntervalTimerCore` のテストで固定してある（36本）。
実機でしか確かめられないのは次の3つ。

- 腕を下ろして画面が消え、30秒後に上げてもズレていないこと（基準7）
- 屋外・直射日光下での視認性
- `HKWorkoutSession` 稼働中のバッテリー消費（60分の練習で許容範囲か）

シミュレータではプロセスを30秒 `SIGSTOP` して、復帰後にズレが無いことを確認済み（基準6）。

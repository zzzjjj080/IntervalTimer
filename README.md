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
  Widget-Info.plist         コンプリケーション用。NSExtension を実ファイルで書く
  IntervalTimer/
    Models/Runner.swift     画面とエンジンをつなぐ
    Services/               ハプティクス、HKWorkoutSession
    Views/                  設定・実行・終了
      Components/SegmentRing.swift  区切りぶんに分かれた円環
  IntervalTimerWidget/      文字盤のコンプリケーション（押すとアプリが開く）
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

## 区切りの合図

| いつ | 触覚 | 画面 |
|---|---|---|
| ＋ を押した | `.start` | |
| − を押した | `.stop` | |
| 開始した | `.start` ＋ `.notification` | |
| 区切りの**75%が終わった**とき | `.notification` を4回 | 地の色が明るい琥珀へ反転 |
| 区切りが**0**になったとき | 同じ（4回） | 通常の色へ戻り、次の区切りへ |
| 全体が**0**になったとき | 4回 → 少し空けて4回 ＋ `.stop` | 終了画面（いちばん明るい） |

**触覚は `Haptics` に全部集める。** watchOS には iPhone の `intensity` に当たるものが無く、
強さは**種類と回数と間隔**でしか作れない。散らばると強弱の設計ができなくなる。
強くしたいときは `cueTaps` を増やす。

**種類を変えても指では区別できない。** 区切りと全体の終わりは、長さで分けている。

**数字合わせの触覚だけは、合図より弱くする。** 何十回も押すので、
区切りの合図と同じ強さだと疲れる。弱い順に `.click` < `.start`/`.stop` <
`.directionUp`/`.directionDown` < `.notification`。

**アプリ側で出せる強さには上限がある。** 弱いと感じたら、まず端末の
設定 → サウンドと触覚 → 触覚の強さ を見る。ここが低いと何をしても弱い。

**途中と終わりをわざと同じ強さにしてある。** 練習中は腕を振っているので、
弱い合図では気づけない。全体の終わりだけは**長さ**で区別する。種類を変えても指では分からない。

1区切りが短い設定では途中の合図を出さない（残りぶんが2秒未満になるとき。区切り8秒が境目）。

## 画面の作り

実行中は、**区切りぶんに分かれた円環**の中に数字を置く。1本の弧が1区切りで、
消化済みは塗り、進行中は途中まで塗る。数字を読まなくても、
「いま何区切り目か」と「その中でどこまで来たか」が掴める。

**色は冷たい色から暖かい色へ、時計回りに進む。**（淡い水 → 若緑 → 金 → 琥珀）
位置そのものが進み具合を表すので、暖色まで来ていれば終わりが近いと分かる。
最後の区切りは警告と同じ琥珀にしてある。12色を用意して、分割数に応じて等間隔に選ぶので、
1分割でも12分割でも端から端まで使う。

**まだ来ていないぶんは無彩色にする。** その区切りの色を薄めると濁って見えて、
「まだ来ていない」ではなく「汚れている」ように読める。無彩色にしておくと、
進むにつれて色が入っていく様子がはっきり出る。

**警告と終了のときは色を使わない。** 地の色そのものが合図なので、
そこへ12色を重ねると何が起きたのか分からなくなる。

### 設定画面の1行

`/5分　終わり 23:09` の形。

- **「1区切り 5分00秒」とは書かない。** `/5分` で意味は通るし、そのぶん横幅が空く
- 空いたところに**いま始めたら終わる時刻**を出す。練習の予定と突き合わせるとき、
  20分という長さより「何時に終わるか」のほうが役に立つ
- 現在時刻から出すので `TimelineView(.everyMinute)` で1分ごとに引き直す。秒は要らない
- 24時間表記かどうかは `formatted(date: .omitted, time: .shortened)` で端末の設定に従わせる

### ＋ − は押しっぱなしで動き続ける

`Button` ではなく長押しで受けている。**`Button` は指を離したときにしか呼ばれない**ので、
押しっぱなしを拾えない。`onLongPressGesture(pressing:)` なら押した瞬間と離した瞬間の両方が来る。

速さは `HoldRepeat`（Core）にある。**押した瞬間から走り出させない。**
0.4秒待ってから始めて、20回を過ぎたら倍速。テストで次の3つを固定してある。

- 全体（1〜180）を端から端まで: **8〜16秒**。速すぎると狙った数で止まれない
- 分割（1〜12）を端から端まで: **2秒未満**。ここが遅いと苛立つ
- 1回だけ押したときは待ち時間ゼロ

触覚は連続では間引く（4回に1回）。毎回鳴らすと震えっぱなしになる。

### 設定画面の行の色

- **全体** = 淡い水、**分割** = 若緑。円環の冷たい側から取っている。
  行ごとに色を変えると、どちらをいじっているのか一目で分かる
- **数字は白のまま。** 一度色にしてみたが、いちばん読みたいものが弱くなった。
  色は見出し・単位・地・ボタンで足りる

### ボタンの色

| ボタン | 色 | 理由 |
|---|---|---|
| 開始 | 橙の塗り＋ほぼ黒の文字 | いちばん押すもの。画面で一番目立たせる |
| ＋ − | 若緑 | 押せる場所だと分かればよいので控えめに |
| 一時停止／再開 | 若緑 | 進める操作 |
| リセット | 金 | やめる操作。色は付けても、**開始より目立たせない** |

**実行画面のボタンは、通常と警告で同じ場所に出る。** 警告のときは地が琥珀一色になるので、
そこへ緑や金を載せず、`nil` を渡して単色へ戻す。
どの色も地の色に対して 4.5:1 以上あることをテストで固定してある。

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

## コンプリケーション

文字盤から一発で開くための拡張。`IntervalTimerWidget/` にある。
絵はアプリのアイコンと同じ4分割の円環。対応は circular / corner / inline / rectangular。

**残り時間は出していない。** 出すにはアプリと拡張で状態を共有する必要があり（App Group）、
仕掛けが増える。まずは「押すと開く」だけを確実に動かしている。

配色は `widgetRenderingMode` で分ける。

- **色を出せる文字盤（`.fullColor`）**: 濃いティールの地に、琥珀→金→若緑→淡い水の4色
- **単色に着色される文字盤（`.accented` / `.vibrant`）**: 色相では区別できないので、
  1本目だけ `widgetAccentable()`、残りは薄く。**濃さ**で分ける

**地を置くのが肝。** 地なしで白い輪にすると、明るい文字盤や写真の上で埋もれる。
実寸50ptで地あり／地なしを並べて確認した。

- バンドルID: `com.zzzjjj080.IntervalTimer.Widget`
  （**`.Complication` は Apple に "not available" で弾かれる**）
- `Widget-Info.plist` は同期グループの外。`NSExtension` は `INFOPLIST_KEY_` に対応が無いので実ファイルで書く
- **署名はプロジェクトにターゲットごとに書いてある。** 本体と拡張でバンドルIDが違うため、
  `xcodebuild` のコマンドラインで `PROVISIONING_PROFILE_SPECIFIER` を一括指定すると拡張が必ず落ちる
- プロファイルは2枚要る。`./Tools-MakeProfile.py` で作る

## 設定の保存

プリセットは作らない。**前回の値をそのまま次回の初期値にする**（`@AppStorage`）。
枠を選ばせるより、開いたら前回のままになっているほうが速い。

## 日本語と英語

`Localizable.xcstrings` / `InfoPlist.xcstrings`（アプリ）と、
`IntervalTimerWidget/Localizable.xcstrings`（コンプリケーション）。
元の言語は日本語で、キーは日本語そのもの。

**気をつけるところが3つある。**

1. **`Text(String)` は訳されない。** そのまま出る。訳させたいものは `LocalizedStringKey` で受ける。
   `SmallButton(title:)` と `valueRow(label:)` はこれで一度取りこぼした
2. **訳が空文字だと豆腐（□）が出る。** 英語では「回」に当たる単位が要らないので空にしたが、
   空の `Text` を置くと四角が描かれる。**空なら描かない**分岐が要る
3. **単位つきの数字は String Catalog では拾えない。**（`5分00秒` `47秒`）
   訳文に単位を混ぜると英語版に「分」が残る。`TimeText` が `Locale` を見て組み立てる

`String` を返すところ（ワークアウトのエラー文）は `String(localized:)` で包む。

```bash
# 英語で起動して確かめる
xcrun simctl launch "$W" com.zzzjjj080.IntervalTimer -AppleLanguages "(en)"
```

**英語の名前は `Splits`（仮）。** ストア名は別に決める。

## 実機の中で何が起きているかを読む

シミュレータではヘルスケアの許可を越えられないので、ワークアウトまわりは実機でしか分からない。
**`--console` で実機の `print` を読める。**

```bash
DEVICECTL_CHILD_IT_START="20,4,0" xcrun devicectl device process launch \
  --device <CoreDeviceのID> --console --terminate-existing -t 60 \
  com.zzzjjj080.IntervalTimer
```

`DEVICECTL_CHILD_` を付けた環境変数がアプリへ渡るので、`IT_START` と組み合わせれば
**本人にタップしてもらわずに**実行画面まで入って、そこまでのログを読める。

`WorkoutKeeper` は各段階を `log()` に出している（DEBUG限定）。
「ワークアウトが動いていない」と思ったときは、まずこれを読む。

**緑のランニングマークはアプリの中には出ない。** 文字盤に戻ったときに上部へ出る。
アプリを開いている間はそこに時計が出るだけなので、これを見て
「動いていない」と判断しないこと。

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

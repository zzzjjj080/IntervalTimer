# ストア用スクリーンショット

Apple Watch Series 11 (46mm) のシミュレータで撮ったもの。**416 × 496 px** で、
App Store Connect の `APP_WATCH_SERIES_10` の枠にそのまま入る。加工していない。

| ファイル | 画面 |
|---|---|
| `01-setup.png` | 設定（初期値の20分・4分割。1区切りが即座に出る） |
| `02-running.png` | 実行中。全体の残りと、いまの区切りの残りを同時に出す |
| `03-warning.png` | 残り20%。**画面ごと明るい琥珀に反転する** |
| `04-done.png` | 終了 |

## 撮り直しかた

```bash
W=$(xcrun simctl list devices | grep "Apple Watch Series 11 (46mm)" | grep -o '[0-9A-F-]\{36\}')
xcrun simctl spawn "$W" defaults delete com.zzzjjj080.IntervalTimer   # 初期値に戻す
SIMCTL_CHILD_IT_NO_WORKOUT=1 SIMCTL_CHILD_IT_START="20,4,255" \
  xcrun simctl launch "$W" com.zzzjjj080.IntervalTimer                # 例: 警告の画面
xcrun simctl io "$W" screenshot store/03-warning.png
```

**UDIDで名指しすること。** 他のスレッドが別のシミュレータを使っていることがあり、
`booted` だと撮る端末を取り違える（引き継ぎ書 4-4 / 4-59）。
**このスクリプトは他の端末を落とさない。**

`IT_START` などの入口は DEBUG 構成にしか無い（→ 親の README）。
数字そのものは本物で、状態へ直接入るだけ。

## 承知のうえの見え方

**`04-done.png` は、右上のシステム時計が地の色に埋もれる。**
終了画面をわざといちばん明るくしているため（屋外で「終わった」と分かるように）。
時計の色はアプリ側から変えられない。気になるなら、この1枚をストアに出さないか、
終了画面の地の色を暗くするかのどちらか。**中身の不具合ではない。**

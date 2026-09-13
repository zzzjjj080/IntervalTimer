#!/bin/bash
# iPhone 実機へ入れる。
# iPhone に繋いだ状態で叩く（USB。ロック解除しておく）。
set -e
# `xcodebuild | grep` の形でも、ビルドが失敗したらここで止める。
# 無いと前のビルドの .app を入れて「完了」と出してしまう（引き継ぎ書 4-142）
set -o pipefail
cd "$(dirname "$0")/IntervalTimer"

security unlock-keychain -p intervaltimer interval-dist.keychain 2>/dev/null || true

# iPhoneに絞る。ペアリング済みのApple Watchも connected と出るため（引き継ぎ書 4-26）。
# grep の空振りで無言終了しないよう || true を付ける（4-19）。
LINE=$(xcrun devicectl list devices 2>/dev/null | grep '(iPhone' | grep ' connected ' | grep -v 'no DDI' | head -1 || true)
if [ -z "$LINE" ]; then
  echo "→ 起こしにいきます（30秒ほど）"
  ID=$(xcrun devicectl list devices 2>/dev/null | grep '(iPhone' | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || true)
  [ -n "$ID" ] && xcrun devicectl device info details --device "$ID" --timeout 60 >/dev/null 2>&1 || true
  LINE=$(xcrun devicectl list devices 2>/dev/null | grep '(iPhone' | grep ' connected ' | grep -v 'no DDI' | head -1 || true)
fi
if [ -z "$LINE" ]; then
  echo "❌ iPhoneが接続されていません（USBで繋いで、ロックを解除してください）"
  exit 1
fi
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
echo "→ $(echo "$LINE" | sed -E 's/.*connected +//') にインストールします"

# 実機の設定画面のいちばん下に出す印（BuildInfo）。**手で増やさない。**
# b<コミット数> とビルド時刻。まだコミットしていない変更があれば + を付ける。
# 中に入る Watch アプリにも同じ印が入る
STAMP="b$(git -C .. rev-list --count HEAD)$(git -C .. diff --quiet HEAD -- . 2>/dev/null || echo +) $(date '+%m/%d %H:%M')"

xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Debug \
  -destination "platform=iOS,id=$DEV" -destination-timeout 30 -derivedDataPath /tmp/it-phone \
  IT_BUILD_STAMP="$STAMP" build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/it-phone/Build/Products/Debug-iphoneos/IntervalTimer.app 2>&1 | grep -E "bundleID"
echo "✅ 完了。iPhone とペアリング中の Apple Watch の両方に入ります"
echo "   設定画面のいちばん下に「$STAMP」が出ていれば、入れ替わっています"

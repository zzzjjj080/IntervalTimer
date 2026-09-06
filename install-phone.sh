#!/bin/bash
# iPhone 実機へ入れる。
# iPhone に繋いだ状態で叩く（USB。ロック解除しておく）。
set -e
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

xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Debug \
  -destination "platform=iOS,id=$DEV" -destination-timeout 30 -derivedDataPath /tmp/it-phone \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/it-phone/Build/Products/Debug-iphoneos/IntervalTimer.app 2>&1 | grep -E "bundleID"
echo "✅ 完了。iPhone とペアリング中の Apple Watch の両方に入ります"

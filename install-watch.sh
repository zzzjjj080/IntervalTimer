#!/bin/bash
# 修正のたびに Apple Watch へ入れるためのスクリプト。
# 接続中のWatchを自動で選ぶので、機種を変えても書き換え不要。
#
# 前提：WatchがMacから見えている必要がある。
#   - Watchを腕に着けてロックを解除する
#   - ペアリング済みのiPhoneをMacにUSBで繋ぐ（Watchは同じWi-Fi経由で見える）
#   - Xcode → Window → Devices and Simulators で Watch が出ていること
# `available (paired)` は「前にペアリングしただけで今は使えない」。これを選ぶと
# developer disk image のマウントで10分待たされる（引き継ぎ書 4-20）。
set -e
cd "$(dirname "$0")/IntervalTimer"

# Watchに絞る。iPhoneも connected と出るので、機種名で選び分ける。
# no DDI は「中身を送れない状態」なので除く。
# grep の空振りで無言終了しないよう || true を付ける（4-19）。
LINE=$(xcrun devicectl list devices 2>/dev/null | grep -i 'Apple Watch' | grep ' connected ' | grep -v 'no DDI' | head -1 || true)
if [ -z "$LINE" ]; then
  echo "❌ Apple Watch が接続されていません。"
  echo "   Watchを腕に着けてロックを解除し、ペアリング中のiPhoneをMacに繋いでください。"
  echo "   いまの状態:"
  xcrun devicectl list devices 2>/dev/null | grep -i 'watch' || echo "   （Watchが1台も見えていません）"
  exit 1
fi
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
MODEL=$(echo "$LINE" | sed -E 's/.*connected +//')
echo "→ ${MODEL} にインストールします"

xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Debug \
  -destination "platform=watchOS,id=$DEV" -destination-timeout 30 -derivedDataPath /tmp/it-device \
  -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/it-device/Build/Products/Debug-watchos/IntervalTimer.app 2>&1 | grep -E "bundleID"
echo "✅ 完了。Watchのホーム画面に「インターバル」が出ます"

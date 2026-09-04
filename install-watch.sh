#!/bin/bash
# 修正のたびに Apple Watch へ入れるためのスクリプト。
# 接続中のWatchを自動で選ぶので、機種を変えても書き換え不要。
#
# 前提：WatchがMacから見えている必要がある。
#   - Watchを腕に着けてロックを解除する（外していると届かない）
#   - ペアリング済みのiPhoneをMacにUSBで繋いで、ロックを解除する
#   - MacとWatchが同じWi-Fiにいる
# `available (paired)` は「前にペアリングしただけで今は使えない」。これを選ぶと
# developer disk image のマウントで10分待たされる（引き継ぎ書 4-20）。
#
# 署名は**手動**にしてある。Xcodeにアカウントを追加していないため、自動署名は
# "No Accounts" で止まり、ワイルドカードのプロファイルに落ちて
# 「HealthKit が無い」と言われる。プロファイルは ./Tools-MakeProfile.py で作る。
set -e
cd "$(dirname "$0")"
ROOT="$PWD"
PROFILE="IntervalTimer watchOS Development"

# プロファイルが手元に無ければ作る（期限切れ・端末追加のときは自分で叩き直す）
if ! ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision >/dev/null 2>&1 ||
   ! grep -rlq "$PROFILE" ~/Library/MobileDevice/Provisioning\ Profiles/ 2>/dev/null; then
  echo "→ プロビジョニングプロファイルを作ります"
  "$ROOT/Tools-MakeProfile.py"
fi

# Watchに絞る。iPhoneも connected と出るので機種名で選び分ける。
# no DDI は「中身を送れない状態」なので除く。
# grep の空振りで無言終了しないよう || true を付ける（引き継ぎ書 4-19）。
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

cd "$ROOT/IntervalTimer"
xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Debug \
  -destination "platform=watchOS,id=$DEV" -destination-timeout 30 -derivedDataPath /tmp/it-device \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=A7WA598R44 \
  CODE_SIGN_IDENTITY="Apple Development" \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/it-device/Build/Products/Debug-watchos/IntervalTimer.app 2>&1 | grep -E "bundleID"
echo "✅ 完了。Watchのホーム画面に「インターバル」が出ます"

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
# 本体とコンプリケーションで2枚要る（バンドルIDが別なので）。
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

# 一覧を眺めるだけでは繋がらない。**こちらから話しかけるとトンネルが張られる。**
# `available (paired)` のまま何十分も待っていたのに、この1行で即 connected になった。
if [ -z "$LINE" ]; then
  echo "→ 起こしにいきます（30秒ほど）"
  ID=$(xcrun devicectl list devices 2>/dev/null | grep -i 'Apple Watch' | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || true)
  [ -n "$ID" ] && xcrun devicectl device info details --device "$ID" --timeout 60 >/dev/null 2>&1 || true
  LINE=$(xcrun devicectl list devices 2>/dev/null | grep -i 'Apple Watch' | grep ' connected ' | grep -v 'no DDI' | head -1 || true)
fi

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
# 署名はプロジェクト側にターゲットごとに書いてある。
# 本体とコンプリケーションで別のプロファイルが要るので、
# コマンドラインで一括指定すると拡張のほうが必ず落ちる。
xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Debug \
  -destination "platform=watchOS,id=$DEV" -destination-timeout 30 -derivedDataPath /tmp/it-device \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/it-device/Build/Products/Debug-watchos/IntervalTimer.app 2>&1 | grep -E "bundleID"
echo "✅ 完了。Watchのホーム画面に「インターバル」が出ます"

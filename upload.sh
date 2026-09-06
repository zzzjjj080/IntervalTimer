#!/bin/bash
# アーカイブを作って App Store Connect へ上げる。
#
# **注意：このスクリプトの「アップロード」部分は watchOS では通らない。**
#
#   error: exportArchive exportOptionsPlist error for key "method"
#          expected one {release-testing, enterprise, debugging} but found app-store-connect
#
# 原因はアカウントではない（追加しても同じ）。**Xcode に watchOS 用の
# App Store 配布方式が存在しない。** 配布ログにこう出る。
#
#   Accepted: WatchOSAdHoc / WatchOSEnterprise / WatchOSDevelopmentSigned
#   Rejected: iOSAppStoreDistribution ... does not support distributing archive
#
# IDEDistribution.framework の中にも WatchOS の App Store クラスが無い。
# 一方で IDEArchiveWatchOnlyAppContainer / ArchiveReformatterEmbeddedWatchAppSupport は
# あるので、**Organizer（GUI）は watch 単体アプリを組み替えて出せる可能性が高い。**
#
# したがって当面はこう使う:
#   1. このスクリプトでアーカイブまで作る（Organizer から見える場所に置かれる）
#   2. Xcode → Window → Organizer → Distribute App から出す
#
# 配布用の証明書とプロファイルは ./Tools-MakeProfile.py が作る（作成済み）。
# 署名鍵は専用キーチェーン interval-dist に入れてある。
set -e
cd "$(dirname "$0")/IntervalTimer"

security unlock-keychain -p intervaltimer interval-dist.keychain 2>/dev/null || true

echo "→ アーカイブ"
DIR=~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)
mkdir -p "$DIR"
rm -rf "$DIR/IntervalTimer.xcarchive"
xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Release \
  -destination 'generic/platform=watchOS' \
  -archivePath "$DIR/IntervalTimer.xcarchive" archive 2>&1 | grep -E "error:|ARCHIVE"

A="$DIR/IntervalTimer.xcarchive/Products/Applications/IntervalTimer.app"
echo "→ 上げる前の点検"
echo "   版 $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $A/Info.plist) ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' $A/Info.plist))"
printf "   HealthKit の権限: "; codesign -d --entitlements - "$A" 2>/dev/null | tr ',' '\n' | grep -ci healthkit
printf "   確認用の入口: "; strings "$A/IntervalTimer" | grep -cE "IT_START|IT_NO_WORKOUT|WorkoutKeeper\]" || true
printf "   拡張: "; ls "$A/PlugIns"

echo
echo "✅ アーカイブができた: $DIR/IntervalTimer.xcarchive"
echo "   Xcode → Window → Organizer → Distribute App から出してください。"
echo "   （watchOS はコマンドラインから App Store へ出せません。理由は上のコメント）"

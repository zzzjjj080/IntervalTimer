#!/bin/bash
# アーカイブを作って App Store Connect へ上げる。
#
# **前提：Xcode に Apple ID が追加されていること。**
#   Xcode → Settings → Accounts → ＋ → Apple ID
# 追加されていないと、書き出しの方式一覧に app-store-connect が出ず、
#   error: exportArchive exportOptionsPlist error for key "method"
#          expected one {release-testing, enterprise, debugging} but found app-store-connect
# で必ず止まる。APIキーを渡しても、この一覧の判定はアカウントを見ている。
#
# 配布用の証明書とプロファイルは ./Tools-MakeProfile.py が作る（作成済み）。
# 署名鍵は専用キーチェーン interval-dist に入れてある。
set -e
cd "$(dirname "$0")/IntervalTimer"

security unlock-keychain -p intervaltimer interval-dist.keychain 2>/dev/null || true

echo "→ アーカイブ"
rm -rf /tmp/IT.xcarchive
xcodebuild -project IntervalTimer.xcodeproj -scheme IntervalTimer -configuration Release \
  -destination 'generic/platform=watchOS' -archivePath /tmp/IT.xcarchive \
  archive 2>&1 | grep -E "error:|ARCHIVE"

A=/tmp/IT.xcarchive/Products/Applications/IntervalTimer.app
echo "→ 上げる前の点検"
echo "   版 $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $A/Info.plist) ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' $A/Info.plist))"
printf "   HealthKit の権限: "; codesign -d --entitlements - "$A" 2>/dev/null | tr ',' '\n' | grep -ci healthkit
printf "   確認用の入口: "; strings "$A/IntervalTimer" | grep -cE "IT_START|IT_NO_WORKOUT|WorkoutKeeper\]" || true
printf "   拡張: "; ls "$A/PlugIns"

echo "→ 書き出してアップロード"
rm -rf /tmp/it-export
xcodebuild -exportArchive -archivePath /tmp/IT.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/it-export \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_CH8R5RJGXQ.p8 \
  -authenticationKeyID CH8R5RJGXQ \
  -authenticationKeyIssuerID cfeb84ca-47e6-45b2-8c5f-192212240b6c
echo "✅ Upload succeeded と出ていれば成功"

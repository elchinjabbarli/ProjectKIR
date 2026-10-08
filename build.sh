#!/bin/bash
# PROJECT KIR — derleme yardımcısı (spec 242).
# Kullanım:
#   ./build.sh            → Debug simülatör derlemesi
#   ./build.sh release    → Release device archive öncesi derleme
#   ./build.sh run        → ilk simülatörde çalıştır

set -euo pipefail
cd "$(dirname "$0")"

SCHEME="ProjectKIR"
PROJ="ProjectKIR.xcodeproj"
CONFIG="Debug"

if [ "${1:-}" = "release" ]; then
  CONFIG="Release"
fi

# Proje dosyası yoksa XcodeGen ile üret (alternatif yol).
if [ ! -d "$PROJ" ]; then
  if command -v xcodegen >/dev/null 2>&1; then
    echo "[KIR] project.pbxproj bulunamadı — XcodeGen ile üretiliyor..."
    xcodegen generate
  else
    echo "[KIR] HATA: $PROJ yok ve xcodegen kurulu değil."
    echo "       brew install xcodegen && xcodegen generate"
    exit 1
  fi
fi

# Ortak xcodebuild bayrakları
FLAGS=(-project "$PROJ" -scheme "$SCHEME" -configuration "$CONFIG")

if [ "${1:-}" = "run" ]; then
  # İlk iOS simülatörünü bul ve çalıştır
  DEST=$(xcrun simctl list devices available | grep -m1 -o '[0-9A-F-]\{36\}')
  if [ -z "$DEST" ]; then
    echo "[KIR] Kullanılabilir simülatör yok."
    exit 1
  fi
  xcodebuild "${FLAGS[@]}" -destination "id=$DEST" build
  APP=$(find ~/Library/Developer/Xcode/DerivedData -name "ProjectKIR.app" -path "*$CONFIG*" -newer "$PROJ" | head -1 || true)
  if [ -n "$APP" ]; then
    xcrun simctl boot "$DEST" 2>/dev/null || true
    open -a Simulator 2>/dev/null || true
    xcrun simctl install "$DEST" "$APP"
    xcrun simctl launch "$DEST" com.placeholder.projectkir
    echo "[KIR] Uygulama simülatörde çalışıyor."
  fi
  exit 0
fi

echo "[KIR] $CONFIG derlemesi başlıyor..."
xcodebuild "${FLAGS[@]}" -destination 'generic/platform=iOS Simulator' build

echo "[KIR] Derleme tamam."

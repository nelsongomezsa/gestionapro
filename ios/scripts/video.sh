#!/bin/zsh
# Vídeo corto del simulador recorriendo la app (modo oscuro), en docs/video/recorrido.mp4.
#
# Uso:  CAPTURAS_EMAIL=... CAPTURAS_PASSWORD=... ios/scripts/video.sh [http://localhost:8081]
# Usa el recorrido testVideoRecorrido de CapturasUITests (no guarda capturas).
set -uo pipefail

api=${1:-}
: ${CAPTURAS_EMAIL:?Falta CAPTURAS_EMAIL}
: ${CAPTURAS_PASSWORD:?Falta CAPTURAS_PASSWORD}
dispositivo=${CAPTURAS_DISPOSITIVO:-iPhone 18 Pro}

raiz=${0:A:h:h:h}
cd "$raiz/ios"
xcodegen generate >/dev/null
udid=$(xcrun simctl list devices available | grep -F "$dispositivo (" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" >/dev/null
xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl ui "$udid" appearance dark

extra=()
[[ -n "$api" ]] && extra=("API_BASE_URL=$api")
mkdir -p "$raiz/docs/video"
tmp=$(mktemp -d -t video)
log="$tmp/test.log"

# Compila antes de grabar, para que el vídeo empiece con la app y no con la espera.
xcodebuild build-for-testing -project GestionApPro.xcodeproj -scheme Capturas \
  -destination "platform=iOS Simulator,id=$udid" -derivedDataPath build "${extra[@]}" > "$log" 2>&1 || { tail -20 "$log"; exit 1; }

xcrun simctl io "$udid" recordVideo --codec=h264 --force "$tmp/bruto.mp4" 2>/dev/null &
grabando=$!
sleep 2
TEST_RUNNER_CAPTURAS_DIR="$tmp/capturas" \
TEST_RUNNER_CAPTURAS_EMAIL="$CAPTURAS_EMAIL" \
TEST_RUNNER_CAPTURAS_PASSWORD="$CAPTURAS_PASSWORD" \
xcodebuild test-without-building -project GestionApPro.xcodeproj -scheme Capturas \
  -destination "platform=iOS Simulator,id=$udid" -derivedDataPath build \
  -only-testing:"GestionApProUITests/CapturasUITests/testVideoRecorrido" > "$log" 2>&1 &
pid=$!
until grep -q "Test Suite 'Selected tests' \(passed\|failed\)" "$log" || ! kill -0 $pid 2>/dev/null; do sleep 1; done
kill -INT $grabando; wait $grabando 2>/dev/null
for _ in {1..10}; do kill -0 $pid 2>/dev/null || break; sleep 2; done
kill $pid 2>/dev/null
grep -E "error:|Test Suite 'Selected tests' (passed|failed)" "$log" | cut -c1-250

# Más pequeño para el repositorio: 540 px de ancho, 30 fps y H.264 (se ve en GitHub y en cualquier navegador).
if command -v ffmpeg >/dev/null; then
  ffmpeg -loglevel error -y -i "$tmp/bruto.mp4" -vf "scale=540:-2,fps=30" -c:v libx264 -crf 30 -preset slow \
    -pix_fmt yuv420p -movflags +faststart -an "$raiz/docs/video/recorrido.mp4"
else
  echo "Sin ffmpeg (brew install ffmpeg): se guarda el vídeo sin comprimir"
  cp "$tmp/bruto.mp4" "$raiz/docs/video/recorrido.mp4"
fi
ls -lh "$raiz/docs/video/recorrido.mp4"
xcrun simctl ui "$udid" appearance light
xcrun simctl status_bar "$udid" clear
rm -rf "$tmp"

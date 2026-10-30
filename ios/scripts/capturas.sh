#!/bin/zsh
# Capturas de una fase en modo claro y oscuro, en docs/capturas/<fase>/{claro,oscuro}/.
#
# Uso:  CAPTURAS_EMAIL=... CAPTURAS_PASSWORD=... ios/scripts/capturas.sh 4A [http://localhost:8081]
# Necesita la API en marcha en esa URL (por defecto la de Debug, localhost:8080).
# Opcional: CAPTURAS_INQUILINO_EMAIL y CAPTURAS_INQUILINO_PASSWORD para las pantallas del inquilino.
set -uo pipefail

fase=${1:?Indica la fase, p. ej. 4A}
api=${2:-}
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

extra=()
# Por línea de comandos la URL va tal cual (el truco "/$()/" solo hace falta en .xcconfig).
[[ -n "$api" ]] && extra=("API_BASE_URL=$api") && echo "API: $api"
log=$(mktemp -t capturas)
fallos=0

for modo in claro oscuro; do
  [[ $modo == claro ]] && xcrun simctl ui "$udid" appearance light || xcrun simctl ui "$udid" appearance dark
  # CAPTURAS_CARPETA cambia la carpeta de destino (p. ej. rediseno/inicio).
  destino="$raiz/docs/capturas/${CAPTURAS_CARPETA:-$fase}/$modo"
  rm -rf "$destino"
  echo "== $fase ($modo)"
  TEST_RUNNER_CAPTURAS_DIR="$destino" \
  TEST_RUNNER_CAPTURAS_EMAIL="$CAPTURAS_EMAIL" \
  TEST_RUNNER_CAPTURAS_PASSWORD="$CAPTURAS_PASSWORD" \
  TEST_RUNNER_CAPTURAS_INQUILINO_EMAIL="${CAPTURAS_INQUILINO_EMAIL:-}" \
  TEST_RUNNER_CAPTURAS_INQUILINO_PASSWORD="${CAPTURAS_INQUILINO_PASSWORD:-}" \
  xcodebuild test -project GestionApPro.xcodeproj -scheme Capturas \
    -destination "platform=iOS Simulator,id=$udid" -derivedDataPath build \
    -only-testing:"GestionApProUITests/CapturasUITests/test$fase" "${extra[@]}" > "$log" 2>&1 &
  pid=$!
  # xcodebuild a veces no termina tras acabar los UI tests: se espera al resumen final
  # ("Selected tests" ... "Executed") y, si no sale solo en 20 s, se cierra.
  until grep -q "Test Suite 'Selected tests' \(passed\|failed\)" "$log" || ! kill -0 $pid 2>/dev/null; do sleep 2; done
  for _ in {1..10}; do kill -0 $pid 2>/dev/null || break; sleep 2; done
  kill $pid 2>/dev/null
  grep -E "error:|Test Suite 'Selected tests' (passed|failed)" "$log" | cut -c1-250
  grep -q "Test Suite 'Selected tests' passed" "$log" || fallos=1
  # Mitad de resolución: se leen bien en GitHub y el repositorio no crece de más.
  for f in "$destino"/*.png(N); do sips -Z 1311 "$f" >/dev/null; done
  # Y comprimidas (paleta de colores): ocupan una cuarta parte sin diferencia visible.
  command -v pngquant >/dev/null && pngquant --quality=70-95 --speed 1 --skip-if-larger --force --ext .png --strip "$destino"/*.png(N) 2>/dev/null
  ls "$destino" 2>/dev/null | wc -l | xargs echo "capturas:"
done

xcrun simctl ui "$udid" appearance light
xcrun simctl status_bar "$udid" clear
rm -f "$log"
exit $fallos

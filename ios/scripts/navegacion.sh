#!/bin/zsh
# Test de interfaz que toca cada enlace de la app (NavegacionUITests).
# Uso:  CAPTURAS_EMAIL=... CAPTURAS_PASSWORD=... ios/scripts/navegacion.sh http://localhost:8081
# Necesita la API en marcha en esa URL (una base de pruebas, nunca la real).
set -uo pipefail
api=${1:?Indica la URL de la API de pruebas}
: ${CAPTURAS_EMAIL:?Falta CAPTURAS_EMAIL}
: ${CAPTURAS_PASSWORD:?Falta CAPTURAS_PASSWORD}
raiz=${0:A:h:h:h}
cd "$raiz/ios"
xcodegen generate >/dev/null
log=$(mktemp -t navegacion)
dir=${NAVEGACION_DIR:-$(mktemp -d)}
echo "Capturas de fallos: $dir"
TEST_RUNNER_CAPTURAS_DIR="$dir" \
TEST_RUNNER_CAPTURAS_EMAIL="$CAPTURAS_EMAIL" \
TEST_RUNNER_CAPTURAS_PASSWORD="$CAPTURAS_PASSWORD" \
xcodebuild test -project GestionApPro.xcodeproj -scheme Capturas \
  -destination "platform=iOS Simulator,name=${CAPTURAS_DISPOSITIVO:-iPhone 18 Pro}" -derivedDataPath build \
  -only-testing:"GestionApProUITests/NavegacionUITests${NAVEGACION_TEST:+/$NAVEGACION_TEST}" "API_BASE_URL=$api" > "$log" 2>&1 &
pid=$!
# xcodebuild a veces no termina tras los UI tests: se espera al resumen y, si no sale solo en 20 s, se cierra.
until grep -q "Test Suite 'Selected tests' \(passed\|failed\)" "$log" || ! kill -0 $pid 2>/dev/null; do sleep 2; done
for _ in {1..10}; do kill -0 $pid 2>/dev/null || break; sleep 2; done
kill $pid 2>/dev/null
grep -E "error:|Test Case .*(passed|failed)|Test Suite 'Selected tests' (passed|failed)" "$log" | cut -c1-260
grep -q "Test Suite 'Selected tests' passed" "$log"

#!/usr/bin/env bash
# Build the watch face for one device.
# Usage: ./build.sh [device]   e.g. ./build.sh fr265
set -euo pipefail

DEVICE="${1:-fr265}"
OUT_DIR="bin"
PRG="$OUT_DIR/SageCream-$DEVICE.prg"

if [[ -n "${CONNECTIQ_SDK:-}" ]]; then
    MONKEYC="$CONNECTIQ_SDK/bin/monkeyc"
elif command -v monkeyc >/dev/null 2>&1; then
    MONKEYC="$(command -v monkeyc)"
else
    SDK="$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/*/ 2>/dev/null | sort -V | tail -1 || true)"
    MONKEYC="${SDK%/}/bin/monkeyc"
fi

if [[ ! -x "$MONKEYC" ]]; then
    echo "ERROR: monkeyc not found." >&2
    echo "Install Connect IQ or set CONNECTIQ_SDK to the SDK folder." >&2
    exit 1
fi

if [[ -z "${JAVA_HOME:-}" ]] && [[ -d /opt/homebrew/opt/openjdk ]]; then
    export JAVA_HOME=/opt/homebrew/opt/openjdk
    export PATH="$JAVA_HOME/bin:$PATH"
fi

KEY="${CONNECTIQ_KEY:-$PWD/developer_key.der}"
if [[ ! -f "$KEY" ]]; then
    echo "==> Creating developer key (first run only)..."
    openssl genrsa -out developer_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER \
        -in developer_key.pem -out developer_key.der -nocrypt
    KEY="$PWD/developer_key.der"
fi

mkdir -p "$OUT_DIR"
echo "==> Building for: $DEVICE"
"$MONKEYC" -f monkey.jungle -d "$DEVICE" -o "$PRG" -y "$KEY" -w

echo
echo "OK: $PRG"
echo "Run in the simulator: monkeydo \"$PRG\" $DEVICE"

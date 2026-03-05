#!/bin/bash
# Verify Sigstore signature on a signed agent card
# This script demonstrates build-time verification

set -euo pipefail

SIGNED_CARD="${1:-agent-cards/weather-agent-card.signed.json}"
REPOSITORY="${2:-}"
WORKFLOW="${3:-Sign Agent Card}"

echo "============================================"
echo "Sigstore Agent Card Verification (Build-time)"
echo "============================================"
echo ""

if [ ! -f "$SIGNED_CARD" ]; then
    echo "Error: Signed agent card not found at $SIGNED_CARD"
    echo "Run the GitHub Actions workflow first to sign the card."
    exit 1
fi

echo "Verifying: $SIGNED_CARD"
echo ""

# Check if sigstore-a2a is available
if ! command -v sigstore-a2a &> /dev/null; then
    echo "sigstore-a2a not found. Installing..."
    if [ -d "sigstore-a2a-repo" ]; then
        cd sigstore-a2a-repo
    else
        git clone https://github.com/sigstore/sigstore-a2a.git sigstore-a2a-repo
        cd sigstore-a2a-repo
        uv sync --prerelease=allow
    fi
    
    VERIFY_CMD="uv run sigstore-a2a"
else
    VERIFY_CMD="sigstore-a2a"
fi

# Build verification command
VERIFY_ARGS="verify $SIGNED_CARD"

if [ -n "$REPOSITORY" ]; then
    VERIFY_ARGS="$VERIFY_ARGS --repository $REPOSITORY"
fi

if [ -n "$WORKFLOW" ]; then
    VERIFY_ARGS="$VERIFY_ARGS --workflow \"$WORKFLOW\""
fi

echo "Running: $VERIFY_CMD $VERIFY_ARGS"
echo ""

eval "$VERIFY_CMD $VERIFY_ARGS"

echo ""
echo "✅ Sigstore verification passed!"
echo "   - Signature is valid"
echo "   - Certificate chain verified against Fulcio"
echo "   - Entry found in Rekor transparency log"

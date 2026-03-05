#!/bin/bash
# Verify Kagenti runtime verification status
# This script demonstrates runtime verification

set -euo pipefail

NAMESPACE="${1:-kagenti-demo}"
AGENT_NAME="${2:-weather-agent}"

echo "============================================"
echo "Kagenti Runtime Verification Status"
echo "============================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found"
    exit 1
fi

# Check if the AgentCard CR exists
echo "1. Checking AgentCard CR status..."
echo ""

AGENTCARD_STATUS=$(kubectl get agentcard "$AGENT_NAME" -n "$NAMESPACE" -o json 2>/dev/null || echo "not_found")

if [ "$AGENTCARD_STATUS" == "not_found" ]; then
    echo "   ❌ AgentCard CR not found. Is Kagenti operator installed?"
    exit 1
fi

echo "   AgentCard: $AGENT_NAME"
echo ""

# Extract verification status
VALID_SIGNATURE=$(echo "$AGENTCARD_STATUS" | jq -r '.status.validSignature // "unknown"')
BINDING_STATUS=$(echo "$AGENTCARD_STATUS" | jq -r '.status.bindingStatus.bound // "unknown"')
SPIFFE_ID=$(echo "$AGENTCARD_STATUS" | jq -r '.status.signatureSpiffeId // "N/A"')
KEY_ID=$(echo "$AGENTCARD_STATUS" | jq -r '.status.signatureKeyId // "N/A"')

echo "2. Signature Verification:"
echo "   - Valid Signature: $VALID_SIGNATURE"
echo "   - Key ID: $KEY_ID"
echo ""

echo "3. Identity Binding:"
echo "   - Bound: $BINDING_STATUS"
echo "   - SPIFFE ID: $SPIFFE_ID"
echo ""

# Check conditions
echo "4. Conditions:"
kubectl get agentcard "$AGENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .status.conditions[*]}   - {.type}: {.status} ({.reason}){"\n"}{end}'
echo ""

# Check if the workload has the verification label
echo "5. Workload Verification Label:"
LABEL=$(kubectl get deployment "$AGENT_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.agent\.kagenti\.dev/signature-verified}' 2>/dev/null || echo "not_set")
echo "   - agent.kagenti.dev/signature-verified: $LABEL"
echo ""

# Summary
echo "============================================"
echo "Verification Summary"
echo "============================================"

if [ "$VALID_SIGNATURE" == "true" ] && [ "$BINDING_STATUS" == "true" ]; then
    echo "✅ Runtime verification PASSED"
    echo "   - JWS signature verified against SPIRE trust bundle"
    echo "   - SPIFFE identity bound to trust domain"
elif [ "$VALID_SIGNATURE" == "true" ]; then
    echo "⚠️  Signature valid, identity binding pending"
else
    echo "❌ Runtime verification FAILED or PENDING"
    echo "   Check the Kagenti operator logs for details:"
    echo "   kubectl logs -n kagenti-system -l app=kagenti-operator"
fi

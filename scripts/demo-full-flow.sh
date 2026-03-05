#!/bin/bash
# Full Demo: Sigstore Build-time + Kagenti Runtime Verification
# This script demonstrates the complete multi-layer security flow

set -euo pipefail

NAMESPACE="${NAMESPACE:-kagenti-demo}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Sigstore + Kagenti Multi-Layer Security Demo                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Show the unsigned agent card
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Original Agent Card (Unsigned)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Location: agent-cards/weather-agent-card.json"
echo ""
if [ -f "agent-cards/weather-agent-card.json" ]; then
    echo "Preview:"
    jq -r '{name, description, version, url, skills: [.skills[].name]}' agent-cards/weather-agent-card.json
else
    echo "⚠️  Agent card not found. Create it first."
fi
echo ""

# Step 2: Show the signed agent card (if exists)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Build-Time Signing (Sigstore)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "When the agent card is pushed to GitHub:"
echo "1. GitHub Actions workflow triggers"
echo "2. sigstore-a2a signs the card using OIDC identity"
echo "3. Signature recorded in Rekor transparency log"
echo "4. Signed card committed back to repo"
echo ""

if [ -f "agent-cards/weather-agent-card.signed.json" ]; then
    echo "✅ Signed card found: agent-cards/weather-agent-card.signed.json"
    echo ""
    echo "Attestations preview:"
    jq -r '.attestations | keys' agent-cards/weather-agent-card.signed.json 2>/dev/null || echo "Unable to parse attestations"
else
    echo "⚠️  Signed card not found. Push to GitHub to trigger signing."
fi
echo ""

# Step 3: Show Kagenti deployment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Deploy to Kubernetes with Kagenti"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To deploy the agent:"
echo "  kubectl apply -k k8s/base"
echo ""
echo "This creates:"
echo "  - Namespace: $NAMESPACE"
echo "  - Deployment: weather-agent (with SPIRE sidecar)"
echo "  - Service: weather-agent"
echo "  - AgentCard CR: weather-agent"
echo ""

# Check if running in a cluster
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    echo "Cluster status:"
    
    # Check namespace
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo "  ✅ Namespace exists"
        
        # Check deployment
        if kubectl get deployment weather-agent -n "$NAMESPACE" &> /dev/null; then
            READY=$(kubectl get deployment weather-agent -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
            echo "  ✅ Deployment exists (Ready replicas: ${READY:-0})"
        else
            echo "  ⚠️  Deployment not found"
        fi
        
        # Check AgentCard
        if kubectl get agentcard weather-agent -n "$NAMESPACE" &> /dev/null; then
            echo "  ✅ AgentCard CR exists"
        else
            echo "  ⚠️  AgentCard CR not found (is Kagenti operator installed?)"
        fi
    else
        echo "  ⚠️  Namespace not created yet"
    fi
else
    echo "  ⚠️  No Kubernetes cluster available"
fi
echo ""

# Step 4: Runtime verification
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Runtime Verification (Kagenti)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Kagenti operator verification flow:"
echo "1. Watches for AgentCard CRs"
echo "2. Fetches agent card from /.well-known/agent.json"
echo "3. Verifies JWS signature against SPIRE trust bundle"
echo "4. Validates SPIFFE ID matches trust domain"
echo "5. Labels workload with verification status"
echo "6. Optionally enforces NetworkPolicies"
echo ""

if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    if kubectl get agentcard weather-agent -n "$NAMESPACE" &> /dev/null; then
        echo "AgentCard status:"
        kubectl get agentcard weather-agent -n "$NAMESPACE" -o jsonpath='
  Synced: {.status.conditions[?(@.type=="Synced")].status}
  SignatureVerified: {.status.conditions[?(@.type=="SignatureVerified")].status}
  Bound: {.status.conditions[?(@.type=="Bound")].status}
  SPIFFE ID: {.status.signatureSpiffeId}
'
        echo ""
    fi
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY: Multi-Layer Security"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ LAYER 1: Build-Time (Sigstore)                                  │"
echo "│   • Signs agent card in CI/CD pipeline                         │"
echo "│   • Uses GitHub OIDC for keyless signing                       │"
echo "│   • Records signature in Rekor transparency log                │"
echo "│   • Provides supply chain provenance                           │"
echo "├─────────────────────────────────────────────────────────────────┤"
echo "│ LAYER 2: Runtime (Kagenti)                                      │"
echo "│   • Verifies agent identity at runtime in Kubernetes           │"
echo "│   • Uses SPIRE for workload identity (SPIFFE)                  │"
echo "│   • JWS signatures with x5c certificate chains                 │"
echo "│   • Enforces NetworkPolicies based on verification             │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "This dual-layer approach ensures:"
echo "  ✓ Immutable provenance from CI/CD (who built it, when, from what code)"
echo "  ✓ Runtime identity verification (is this really the agent it claims to be?)"
echo "  ✓ Zero-trust security model (verify at every layer)"
echo ""

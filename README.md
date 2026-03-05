# Sigstore + Kagenti Multi-Layer Security Demo

This demo showcases a comprehensive security model for AI agents using:

1. **Sigstore** for build-time signing and supply chain provenance
2. **Kagenti** for runtime verification and identity management

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BUILD TIME (CI/CD)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────────────────┐  │
│   │ agent-card.  │ ──►  │  sigstore-   │ ──►  │ signed-agent-card.json   │  │
│   │    json      │      │    a2a sign  │      │ (Sigstore attestations)  │  │
│   └──────────────┘      └──────────────┘      └──────────────────────────┘  │
│                                │                                            │
│                                ▼                                            │
│                    ┌───────────────────────┐                                │
│                    │ Rekor Transparency Log│                                │
│                    └───────────────────────┘                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        RUNTIME (Kubernetes)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────────────────┐  │
│   │   SPIRE      │ ──►  │  Weather     │ ──►  │ /.well-known/agent.json  │  │
│   │   Server     │      │   Agent Pod  │      │  (JWS signed at startup) │  │
│   └──────────────┘      └──────────────┘      └──────────────────────────┘  │
│         │                      ▲                         │                  │
│         │                      │                         ▼                  │
│         ▼               ┌──────────────┐      ┌──────────────────────────┐  │
│   ┌──────────────┐      │   AgentCard  │ ◄──  │   Kagenti Operator       │  │
│   │ Trust Bundle │      │      CR      │      │   (X5C verification)     │  │
│   │  ConfigMap   │      └──────────────┘      └──────────────────────────┘  │
│   └──────────────┘                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Understanding the Two Security Layers

### Layer 1: Build-Time Signing (Sigstore)

**What it does:**
- Signs the agent card during CI/CD pipeline execution
- Uses GitHub Actions OIDC for keyless signing (no keys to manage!)
- Records the signature in Rekor (public transparency log)
- Optionally adds SLSA provenance metadata

**What it proves:**
- The agent card was built from a specific commit in a specific repository
- The signing happened in a trusted CI/CD environment (GitHub Actions)
- There's an immutable, public record of the signing event

**Format:** DSSE envelope with Sigstore bundle in `attestations` field

### Layer 2: Runtime Verification (Kagenti)

**What it does:**
- Verifies agent identity when pods start in Kubernetes
- Uses SPIRE to issue X.509 certificates with SPIFFE IDs
- Validates JWS signatures on agent cards against SPIRE trust bundle
- Optionally enforces NetworkPolicies based on verification status

**What it proves:**
- The running workload has a cryptographically verified identity
- The agent card served by the pod matches the expected identity
- Only verified agents can communicate with other services

**Format:** JWS with `x5c` certificate chain in `signatures` array

### Why Both Layers?

| Aspect | Sigstore (Build) | Kagenti (Runtime) |
|--------|------------------|-------------------|
| **When** | At build/release time | At pod startup and periodically |
| **Where** | CI/CD pipeline | Kubernetes cluster |
| **Identity** | GitHub repo/workflow | SPIFFE ID |
| **Trust Root** | Sigstore public (Fulcio/Rekor) | SPIRE trust bundle |
| **Proves** | "This came from trusted source" | "This pod is who it claims to be" |

## Prerequisites

- Kubernetes cluster (kind, minikube, or cloud)
- kubectl configured
- SPIRE deployed (for Kagenti runtime verification)
- Kagenti operator installed
- GitHub repository (for CI/CD signing)
- Python 3.11+ with UV (for local sigstore-a2a)

## Quick Start

### 1. Clone and Setup

```bash
# Already in this repo!
cd sigstore-kagenti

# Make scripts executable
chmod +x scripts/*.sh
```

### 2. Deploy Kagenti Prerequisites

```bash
# Install SPIRE (if not already installed)
# See: https://spiffe.io/docs/latest/try/getting-started-kubernetes/

# Install Kagenti operator
# See: https://github.com/kagenti/kagenti-operator
helm repo add kagenti https://kagenti.github.io/helm-charts
helm install kagenti-operator kagenti/kagenti-operator -n kagenti-system --create-namespace
```

### 3. Deploy the Weather Agent

```bash
# Apply Kubernetes manifests
kubectl apply -k k8s/base

# Verify deployment
kubectl get pods -n kagenti-demo
kubectl get agentcard -n kagenti-demo
```

### 4. Trigger Build-Time Signing

Push to GitHub to trigger the signing workflow:

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin git@github.com:YOUR_ORG/sigstore-kagenti.git
git push -u origin main
```

The GitHub Actions workflow will:
1. Sign `agent-cards/weather-agent-card.json`
2. Verify the signature
3. Commit the signed card back

### 5. Run the Demo

```bash
# Full demo walkthrough
./scripts/demo-full-flow.sh

# Verify Sigstore signature (build-time)
./scripts/verify-sigstore-signature.sh

# Check Kagenti runtime status
./scripts/verify-kagenti-runtime.sh
```

## File Structure

```
sigstore-kagenti/
├── .github/
│   └── workflows/
│       └── sign-agent-card.yml    # GitHub Actions workflow for signing
├── agent-cards/
│   ├── weather-agent-card.json    # Original agent card
│   └── weather-agent-card.signed.json  # Signed card (generated)
├── k8s/
│   └── base/
│       ├── namespace.yaml
│       ├── weather-agent-deployment.yaml
│       ├── agentcard-cr.yaml      # Kagenti AgentCard CR
│       └── kustomization.yaml
├── scripts/
│   ├── demo-full-flow.sh
│   ├── verify-sigstore-signature.sh
│   └── verify-kagenti-runtime.sh
└── README.md
```

## Deep Dive: Sigstore A2A Signing

### Agent Card Before Signing

```json
{
  "protocolVersion": "0.2.9",
  "name": "Weather Service Agent",
  "description": "...",
  "url": "http://weather-agent.default.svc.cluster.local:8000",
  "version": "0.0.1-alpha.3",
  "capabilities": {...},
  "skills": [...]
}
```

### Agent Card After Signing

```json
{
  "agentCard": {
    "protocolVersion": "0.2.9",
    "name": "Weather Service Agent",
    ...
  },
  "attestations": {
    "signatureBundle": {
      "mediaType": "application/vnd.dev.sigstore.bundle.v0.3+json",
      "verificationMaterial": {
        "certificate": {...},
        "timestampVerificationData": {...}
      },
      "dsseEnvelope": {
        "payload": "<base64-encoded-agent-card>",
        "payloadType": "application/vnd.in-toto+json",
        "signatures": [...]
      }
    },
    "provenanceBundle": {
      "provenance": {...}
    }
  }
}
```

### Verification Constraints

When verifying, you can constrain:
- `--identity`: The exact workflow ref that signed
- `--identity_provider`: The OIDC issuer (GitHub)
- `--repository`: The GitHub repository
- `--workflow`: The workflow name

## Deep Dive: Kagenti Runtime Verification

### AgentCard CR Status

```yaml
status:
  validSignature: true
  signatureKeyId: "abc123..."
  signatureSpiffeId: "spiffe://cluster.local/ns/kagenti-demo/sa/weather-agent"
  bindingStatus:
    bound: true
    reason: "IdentityMatched"
  conditions:
    - type: Synced
      status: "True"
    - type: SignatureVerified  
      status: "True"
    - type: Bound
      status: "True"
  card:
    name: "Weather Service Agent"
    url: "http://weather-agent:8000"
    ...
```

### Verification Flow

1. **Fetch**: GET `/.well-known/agent.json` from agent service
2. **Extract x5c**: Read X.509 chain from JWS protected header
3. **Validate chain**: Verify against SPIRE trust bundle ConfigMap
4. **SPIFFE ID**: Extract from leaf certificate SAN URI
5. **Canonical JSON**: Rebuild payload (sorted keys, no `signatures`)
6. **JWS verify**: Validate signature with leaf public key
7. **Identity binding**: Match SPIFFE ID to trust domain

### Operator Flags

| Flag | Default | Effect |
|------|---------|--------|
| `--require-a2a-signature` | false | Require valid JWS signatures |
| `--signature-audit-mode` | false | Log failures without blocking |
| `--enforce-network-policies` | false | Create NetworkPolicies |

## Integrating Both Layers

The two layers use **different signature formats** and serve **different purposes**:

1. **Sigstore** signs the agent card definition in your repository
2. **Kagenti** signs the agent card served by the running pod at runtime

For a complete integration, you could:

1. Store the Sigstore-signed card alongside the deployment
2. Have the agent serve the original card at `/.well-known/agent.json`  
3. Have the agent also serve the Sigstore-signed version at `/.well-known/agent.signed.json`
4. Verify both: Sigstore for provenance, Kagenti for runtime identity

## Troubleshooting

### Sigstore Signing Fails

```bash
# Check GitHub Actions logs
# Ensure id-token: write permission is set
# Verify OIDC token is available
```

### Kagenti Verification Fails

```bash
# Check operator logs
kubectl logs -n kagenti-system -l app=kagenti-operator

# Check SPIRE is running
kubectl get pods -n spire

# Verify trust bundle ConfigMap exists
kubectl get configmap spire-bundle -n spire
```

### Agent Card Not Served

```bash
# Port-forward to agent
kubectl port-forward svc/weather-agent -n kagenti-demo 8000:8000

# Fetch agent card
curl http://localhost:8000/.well-known/agent.json
```

## References

- [Sigstore](https://sigstore.dev)
- [sigstore-a2a](https://github.com/sigstore/sigstore-a2a)
- [Kagenti](https://kagenti.io)
- [A2A Protocol](https://a2a-protocol.org)
- [SPIFFE/SPIRE](https://spiffe.io)
- [SLSA](https://slsa.dev)

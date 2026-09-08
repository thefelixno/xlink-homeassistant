---
# 0.1.0

## Changed

- **Migrated from WireGuard to Tailscale** — No manual key management, no endpoints, no routing rules. Tailscale handles NAT traversal, authentication, and mesh networking automatically.
- Simplified configuration: just an auth key and optional advertisement settings
- New status API with connection state and peer count

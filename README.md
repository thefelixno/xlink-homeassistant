# xLink Client — Home Assistant Add-on

> A [Tailscale](https://tailscale.com) add-on for Home Assistant that connects your instance to your tailnet, providing secure remote access without manual VPN configuration.

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

---

## What It Does

This add-on joins your Home Assistant instance to a [Tailscale](https://tailscale.com) tailnet, giving it:

- **A unique Tailscale IP** (from the `100.x.y.z` magicDNS range)
- **Automatic encrypted mesh networking** — no manual VPN setup
- **NAT traversal** — works behind any firewall or CGNAT
- **Subnet routing** — optionally advertise your local network to the tailnet
- **Exit node support** — optionally use your HA as an exit node
- **Status dashboard** — connection state, peers, and transfer stats

This is ideal for:
- Remotely accessing Home Assistant from anywhere with zero port forwarding
- Exposing your local network (subnets) to your tailnet
- Connecting HA to other services across different networks
- Using your HA machine as a network exit node

---

## Architecture

```
┌──────────────────────────────────────┐
│  Home Assistant Add-on               │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Tailscale Daemon (tailscaled)  │  │  Creates tailscale0 interface
│  │  - Auth via auth key           │  │  with Tailscale IP
│  │  - Automatic reconnection      │  │
│  └────────────────────────────────┘  │
│              │                        │
│         tailscale0                    │
│       (100.x.y.z)                     │
│              │                        │
│  ┌────────────────────────────────┐  │
│  │ socat port forwarder           │  │  Optional: forward local
│  │  (configurable)                │  │  services to tailnet
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Status API (port 80)           │  │  JSON: state, peers, IPs
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
              │
         DERP / Coord
        (Tailscale network)
              │
     ┌────────┴────────┐
     │                 │
┌────▼─────┐    ┌──────▼──────┐
│ Phone/   │    │ Other       │
│ Laptop   │    │ Tailnet     │
│ (your    │    │ devices     │
│ tailnet) │    │             │
└──────────┘    └─────────────┘
```

---

## Installation

### Step 1: Set Up Tailscale

1. If you don't have a Tailscale account, create one at [tailscale.com](https://tailscale.com).
2. Install Tailscale on at least one other device on your network (phone, laptop, server) so you can verify connectivity.

### Step 2: Create an Auth Key

1. Go to your Tailscale admin console: <https://login.tailscale.com/admin/auth-keys>
2. Click **Generate key**.
3. Set:
   - **Reusable**: ✅ (so the add-on can reconnect after restart)
   - **Expires**: Your preferred expiry (or leave as never)
   - **Ephemeral**: ❌ (you want this to be a persistent node)
4. Copy the generated key (starts with `tskey-client-...` or `tskey-auth-...`).

### Step 3: Add the Repository

1. In Home Assistant, go to **Supervisor → Add-on Store → ⋮ → Add-on repositories**.
2. Add:
   ```
   https://github.com/thefelixno/xlink-homeassistant
   ```
3. Refresh — **xLink Client** should appear.

### Step 4: Install & Configure

1. Open **xLink Client** → **Configuration**.
2. Paste your **Auth Key** in the `auth_key` field.
3. (Optional) Configure subnet routing, exit node, or port forwarding (see below).
4. Click **Save** → **Start**.

---

## Configuration

Edit via the **Configuration** tab in the add-on UI.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `auth_key` | `str` | Tailscale auth key (starts with `tskey-...`). Required for first-time authentication. |

### Connection Options

| Field | Type | Description |
|-------|------|-------------|
| `login_server` | `str` | Custom coordination server URL. Only needed for headless/self-hosted setups (e.g., `https://your-headscale-server:8080`). Default: Tailscale's public servers. |
| `hostname` | `str` | Node name in your tailnet. Defaults to the add-on slug (`xlink_client`). |
| `accept_dns` | `bool` | Accept DNS configuration from the tailnet. Default: `false` (recommended to avoid interfering with HA's DNS). |

### Advertisement Options

These options are applied via `tailscale set` and can be changed at any time (even while running).

| Field | Type | Description |
|-------|------|-------------|
| `advertise_routes` | `list<str>` | Subnets to advertise to the tailnet. Example: `["192.168.1.0/24"]` makes your entire LAN reachable from other tailnet devices. |
| `advertise_exit_node` | `bool` | Advertise this node as an exit node. When enabled, all traffic from other tailnet devices can be routed through your HA machine. |
| `advertise_tags` | `list<str>` | ACL tags to apply to this node. Requires an admin-approved ACL or auto-approve in the tailnet settings. Example: `["tag:home", "tag:hass"]`. |

### Port Forwarding (Optional)

Forward a port on the Tailscale interface to a local service:

| Field | Type | Description |
|-------|------|-------------|
| `forward` | `str` | Format: `bind_port:target_host:target_port`. Example: `8123:host.docker.internal:8123` exposes HA on Tailscale port 8123. Leave empty to disable. |

**Examples:**
- `8123:host.docker.internal:8123` — Expose Home Assistant on Tailscale
- `443:homeassistant:443` — Expose HA with SSL
- `9200:elasticsearch:9200` — Expose any service

### Subnet Routing Example

To make your entire home network (`192.168.1.0/24`) reachable from your tailnet:

```yaml
auth_key: "tskey-xxxxxxx"
advertise_routes:
  - "192.168.1.0/24"
accept_dns: false
```

Then in your Tailscale admin console (ACLs), ensure the route is approved:
```json
{
  "type": "routes",
  "values": ["192.168.1.0/24"]
}
```

Or enable **Auto-approve** for subnets in the Tailscale settings.

### Exit Node Example

Use your HA machine as an exit node for all tailnet traffic:

```yaml
auth_key: "tskey-xxxxxxx"
advertise_exit_node: true
```

After connecting, other tailnet devices can route their traffic through your HA by selecting it as the exit node.

---

## Full Configuration Example

```yaml
auth_key: "tskey-client-xxxxxxxxxxxxxxxxxxxxxxxx"
login_server: ""                       # Leave empty for public Tailscale
hostname: "homeassistant"              # Custom node name
accept_dns: false

advertise_routes:
  - "192.168.1.0/24"                   # Advertise home network
advertise_exit_node: false
advertise_tags:
  - "tag:home"
  - "tag:hass"

forward: ""                            # No port forwarding (use tailscale IP directly)
log_level: info
```

---

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `80` | TCP | Status API (JSON response) |

> **Note:** No inbound port forwarding is needed on your router. Tailscale handles all connectivity via DERP relay servers and direct peer-to-peer connections.

---

## Status API

The add-on exposes a JSON endpoint at `http://<addon-ip>:80`:

```bash
# Check status
curl http://172.30.32.1:80

# Example response
{
  "state": "running",
  "node_id": "abc123",
  "node_name": "xlink-client-xyz",
  "tailscale_ips": ["100.115.29.117"],
  "machine_status": "Running",
  "connected_peers": 3,
  "uptime_seconds": 86400
}
```

---

## Accessing Home Assistant Remotely

Once connected, you have **three ways** to reach Home Assistant:

### Method 1: Tailscale IP (Recommended)

Home Assistant is accessible at its Tailscale IP:
```
http://100.115.29.117:8123
```
No configuration changes needed — HA listens on all interfaces by default.

### Method 2: MagicDNS

If MagicDNS is enabled in your tailnet, use the node name:
```
http://xlink-client.your-tailnet.ts.net:8123
```

### Method 3: Advertised Subnet

If you advertised `192.168.1.0/24`, use your HA's actual LAN IP:
```
http://192.168.1.50:8123
```
(other tailnet devices can now reach your LAN through the tunnel)

---

## Home Assistant Proxy Configuration

If you access HA through the Tailscale IP, no special proxy config is needed.

If you access HA through a reverse proxy (Nginx, etc.) that sits between the tailnet and HA:

```yaml
# In Home Assistant configuration.yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.32.0/23    # Docker add-on network
```

---

## Services Running Inside the Add-on

| Service | Description |
|---------|-------------|
| `tailscale` | `tailscaled` daemon — manages the encrypted mesh network |
| `forward` | `socat` port forwarder — exposes local services on the Tailscale interface |
| `status` | HTTP API — reports node state, IPs, and peer count |

---

## Troubleshooting

### Add-on starts but no Tailscale IP appears

1. Check the add-on log — look for authentication errors.
2. Verify your `auth_key` is correct and hasn't expired.
3. Ensure the key is marked as **Reusable**.
4. Check outbound connectivity — the container needs HTTPS access to `login.tailscale.com`.

### Can't reach Home Assistant from other tailnet devices

1. Verify the add-on shows a Tailscale IP (check status API).
2. If using subnet routing, confirm the route is approved in the Tailscale admin console.
3. Check that your local firewall allows inbound connections on port 8123.
4. Ensure HA's `server_host` isn't restricted to `127.0.0.1` — it should listen on all interfaces (`0.0.0.0`).

### Tailscale IP changes after restart

This should **not** happen with a static node key. If it does:
1. Delete the old node from the Tailscale admin console.
2. Restart the add-on — it will re-register with the same key.

### DNS resolution fails on other devices

Set `accept_dns: true` if you want the add-on to push DNS records to the tailnet. Note: this may interfere with your HA instance's DNS if MagicDNS is already enabled elsewhere.

### Port forwarding not working

1. Verify the `forward` format: `bind_port:target_host:target_port`.
2. Test from within the add-on shell: `nc -zv host.docker.internal 8123`.
3. Check that the target service is actually running and accessible.

---

## Migration from WireGuard

If you're migrating from the WireGuard version:

1. **No data migration needed** — Tailscale manages its own state.
2. **Remove WireGuard config** — the new add-on uses a completely different configuration.
3. **Generate a new auth key** — Tailscale auth keys replace WireGuard key pairs.
4. **Simpler setup** — no manual key management, endpoint configuration, or routing rules needed.

---

## Development

### DevContainer

```bash
# Open in VS Code with Dev Containers extension
code .
```

### Build

```bash
# Build for local installation
ha addons build xlink_client
```

---

## License & Credits

- **Author:** Felix Nölte <mail@felixnoelte.de>
- **Repository:** [thefelixno/xlink-homeassistant](https://github.com/thefelixno/xlink-homeassistant)
- Tailscale: [tailscale.com](https://tailscale.com)
- Based on [Home Assistant Add-on Base](https://github.com/hassio-addons/addon-base)

---

*Disclaimer: This add-on is in active development. Configuration options and behavior may change.*

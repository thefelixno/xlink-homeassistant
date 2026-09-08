# xLink Client — Home Assistant Add-on

> A WireGuard-based reverse tunnel add-on for Home Assistant that securely exposes your local Home Assistant (or any service) through a remote gateway endpoint.

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

---

## What It Does

This add-on creates a **persistent WireGuard tunnel** from your Home Assistant instance to a remote gateway server. Once connected, it:

1. Establishes a WireGuard VPN tunnel to a remote **gateway endpoint** (your server in the cloud or at a data center).
2. Runs a **port forwarder** (`socat`) that exposes `localhost:8123` (or any configured target) through the tunnel.
3. Provides a **status API** on port `80` that reports WireGuard peer handshake and transfer statistics as JSON.
4. Generates **peer client configurations** and QR codes for additional WireGuard peers.

This is useful for:
- Remotely accessing your Home Assistant from outside your network.
- Connecting smart home devices that need to reach a cloud gateway.
- Creating a secure reverse tunnel for Home Assistant behind CGNAT or restrictive firewalls.

---

## Architecture

```
┌──────────────────────────────────┐         WireGuard UDP            ┌────────────────────────┐
│  Home Assistant Add-on (HA)      │◄────────────────────────────────►│  Gateway Server         │
│                                  │         (port 51820)             │  (your remote server)   │
│  ┌────────────────────────────┐  │                                  │                         │
│  │ WireGuard (wg-quick)       │  │                                  │  xLink Gateway          │
│  │  - Client interface        │  │                                  │                         │
│  │  - Peer (gateway endpoint) │  │                                  │                         │
│  └────────────────────────────┘  │                                  │                         │
│          │                       │                                  │                         │
│  ┌───────▼───────────────┐       │                                  │                         │
│  │ socat port forwarder  │       │                                  │                         │
│  │ :8080 → host.docker  │       │                                  │                         │
│  │   .internal:8123      │       │                                  │                         │
│  └───────────────────────┘       │                                  │                         │
│                                  │                                  │                         │
│  ┌────────────────────────────┐  │                                  │                         │
│  │ API status endpoint (:80)  │  │                                  │                         │
│  │ JSON: peer stats, HS, Tx/Rx│  │                                  │                         │
│  └────────────────────────────┘  │                                  │                         │
└──────────────────────────────────┘                                  └────────────────────────┘
```

---

## Installation

### Step 1: Add the Repository

1. In Home Assistant, go to **Supervisor → Add-on Store → ⋮ → Add-on repositories**.
2. Add this repository URL:
   ```
   https://github.com/thefelixno/xlink-homeassistant
   ```
3. Refresh the store — you should see **xLink Client** appear.

### Step 2: Install the Add-on

1. Navigate to **xLink Client** in the add-on store.
2. Click **Install**.

---

## Configuration

The add-on configuration is editable via **Configuration** tab in the add-on UI, or by editing `/ssl/addon_configs/xlink_client/config.yaml`.

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `gateway.host` | `str` | Hostname or IP of your remote gateway server (e.g., `endpoint.your-server.de`) |
| `gateway.port` | `int` | UDP port the gateway is listening on (e.g., `5820`) |
| `gateway.public_key` | `str` | WireGuard **public key** of the gateway server |
| `client.private_key` | `str` | WireGuard **private key** for this client (generated on first run if not provided) |

### Optional Fields

#### Server / Tunnel Settings

| Field | Type | Description |
|-------|------|-------------|
| `server.host` | `str` | Hostname for peer endpoint references (used in generated peer configs) |
| `server.addresses` | `list<str>` | IP addresses for the WireGuard interface (e.g., `["172.27.66.1"]`) |
| `server.dns` | `list<str>` | DNS servers for peer client configs |
| `server.interface` | `str` | WireGuard interface name (default: `wg0`) |
| `server.mtu` | `int` | Custom MTU for the tunnel |
| `server.private_key` | `str` | Server's own private key (for peer generation) |
| `server.public_key` | `str` | Server's own public key (for peer generation) |

#### Client Forward Settings

| Field | Type | Description |
|-------|------|-------------|
| `client.forward` | `str` | Target to forward through the tunnel (default: `host.docker.internal:8123`) |

  Examples:
  - `host.docker.internal:8123` — Forward Home Assistant (default)
  - `192.168.1.100:443` — Forward any local HTTPS service
  - `localhost:8123` — Forward from within the container network

#### Peer Configuration (Optional)

Add additional WireGuard peers that can connect **to** this instance:

```yaml
peers:
  - name: hassio
    addresses:
      - 172.27.66.2
    allowed_ips: []          # Defaults to peer addresses
    client_allowed_ips: []   # Defaults to 0.0.0.0/0
    persistent_keep_alive: 25
    endpoint: "peer-host:51820"   # Optional: if this peer initiates connections
```

For each peer, the add-on will:
- Generate (or use provided) WireGuard key pairs
- Create a client configuration file at `/ssl/wireguard/<name>/client.conf`
- Generate a QR code at `/ssl/wireguard/<name>/qrcode.png`
- Register the peer with the status API

---

## Full Configuration Example

```yaml
server:
  host: myautomatedhome.duckdns.org
  addresses:
    - 172.27.66.1
  dns: []

gateway:
  host: "endpoint.your-server.de"
  port: 5820
  public_key: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="

client:
  private_key: "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy="
  forward: "host.docker.internal:8123"

peers: []
#   - name: hassio
#     addresses:
#       - 172.27.66.2
#     allowed_ips: []
#     client_allowed_ips: []

log_level: info   # trace | debug | info | notice | warning | error | fatal
```

---

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `51820` | UDP | WireGuard tunnel endpoint |
| `80` | TCP | Peer status API (JSON response) |

> **Router tip:** Forward port `51820/UDP` on your home router to the Home Assistant machine for inbound peer connections.

---

## Status API

The add-on exposes a JSON API at `http://<addon-ip>:80` (or `http://host.docker.internal:80` from outside) with peer statistics:

```json
[
  {
    "name": "hassio",
    "endpoint": "1.2.3.4:5820",
    "latest_handshake": "1700000000000000000",
    "transfer_rx": "12345",
    "transfer_tx": "67890"
  }
]
```

---

## Home Assistant Proxy Configuration

If you're accessing Home Assistant through the tunnel (e.g., via Nginx reverse proxy), you need to configure HA to trust the proxy:

```yaml
# In your Home Assistant configuration.yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.32.0/23    # Docker add-on network range
    # Or: 127.0.0.1     # If the tunnel endpoint is on the same host
```

---

## Services Running Inside the Add-on

| Service | Description |
|---------|-------------|
| `wireguard` | Starts the WireGuard tunnel via `wg-quick up wg0` |
| `forward` | Runs `socat` to forward tunnel traffic to `client.forward` target |
| `api` | HTTP server exposing WireGuard peer status as JSON on port 80 |
| `status` | One-time `wg show` log after 30s startup delay |

---

## Troubleshooting

### Tunnel won't start

1. Check the add-on log for configuration errors.
2. Verify `gateway.host`, `gateway.port`, and `gateway.public_key` are correct.
3. Ensure `client.private_key` is set (the add-on won't auto-generate it for the client side).
4. Test connectivity: `ping <gateway_host>` from within the add-on shell.

### "Unknown proxy" errors in Home Assistant

Add the trusted proxy configuration shown above in **Proxy Configuration**.

### Port forwarding not working

- Verify `client.forward` points to the correct target.
- From the add-on shell, test with: `telnet host.docker.internal 8123`.
- Check firewall rules on your Home Assistant host.

### Peer status API returns empty

- Ensure peers are configured with valid WireGuard public keys.
- Check that peers have actually connected (look for handshake timestamps).

---

## Development

### DevContainer

This repo includes a Home Assistant devcontainer for local add-on development:

```bash
# Open in VS Code with Dev Containers extension
code .
# Or: docker buildx build -t xlink-client-dev .
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
- Built on [Home Assistant Add-on Base](https://github.com/hassio-addons/addon-base)

This add-on is based on the WireGuard add-on blueprint from the Home Assistant Community Add-ons project.

---

*Disclaimer: This add-on is in active development. Features and configuration options may change.*

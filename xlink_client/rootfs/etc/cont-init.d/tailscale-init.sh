#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: xLink Client (Tailscale)
# Initialize Tailscale configuration
# ==============================================================================

# Ensure state directory exists
mkdir -p /tmp/tailscaled.state ||
    bashio::exit.nok "Could not create Tailscale state directory!"

# Apply advertisement settings via `tailscale set`
ADVERTISE_ROUTES=""
if bashio::config.has_value 'advertise_routes'; then
    ADVERTISE_ROUTES=$(bashio::config 'advertise_routes | join(",")')
fi

ADVERTISE_TAGS=""
if bashio::config.has_value 'advertise_tags'; then
    ADVERTISE_TAGS=$(bashio::config 'advertise_tags | join(",")')
fi

ADVERTISE_EXIT_NODE="false"
if bashio::config.get_bool 'advertise_exit_node'; then
    ADVERTISE_EXIT_NODE="true"
fi

# Build set command
SET_OPTS=""
[ -n "$ADVERTISE_ROUTES" ] && SET_OPTS="$SET_OPTS --advertise-routes=$ADVERTISE_ROUTES"
[ -n "$ADVERTISE_TAGS" ] && SET_OPTS="$SET_OPTS --advertise-tags=$ADVERTISE_TAGS"
[ "$ADVERTISE_EXIT_NODE" = "true" ] && SET_OPTS="$SET_OPTS --advertise-exit-node"

# Apply settings (may fail if not yet connected; that's OK, the service will re-apply)
if [ -n "$SET_OPTS" ]; then
    bashio::log.info "Applying advertisement settings: $SET_OPTS"
    tailscale set $SET_OPTS 2>/dev/null ||
        bashio::log.warning "Could not apply advertisement settings (will retry on connect)"
fi

# Accept DNS configuration
if bashio::config.get_bool 'accept_dns'; then
    bashio::log.info "Enabling DNS acceptance from tailnet"
    tailscale set --accept-dns=true 2>/dev/null || true
fi

bashio::log.info "Tailscale initialization complete"

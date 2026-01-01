#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: WireGuard
# Creates the nginx config
# ==============================================================================

# todo: use different directory, but make sure it is persisted
config_dir="/opt/nginx"
if ! bashio::fs.directory_exists "${config_dir}"; then
    mkdir -p "${config_dir}" ||
        bashio::exit.nok "Could not create nginx config folder!"
fi
config="${config_dir}/nginx.conf"

# Get the target from forward
target="homeassistant:8123"
if ! bashio::config.has_value "client.forward"; then
    target=$(bashio::config "client.forward")
fi

# Write the nginx config
         #       proxy_pass http://${target}/;
         #       proxy_set_header Host \$host;
         #       proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
         #       proxy_set_header X-Forwarded-Proto \$scheme;
         #       proxy_redirect off;
echo "
    events { worker_connections 1024; }

    http {
        server {
            listen 8080;

            location / {
                proxy_pass http://${target}/;
                proxy_set_header Host \$host;
                proxy_set_header X-Forwarded-For 127.0.0.1;
                proxy_set_header X-Forwarded-Proto \$scheme;
                proxy_redirect off;
            }
        }
    }
" > "${config}"


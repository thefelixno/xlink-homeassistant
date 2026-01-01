# xLink Client Add-on: in development

## IMPORTANT: Configure your homeassistant

Allow proxy connections. You can find the right ip address from browsing the homeassistant logs for "unknwon proxy" errors

add this to your configuration.yaml

```ts
http:
  # For extra security set this to only accept connections on localhost if NGINX is on the same machine
  # Uncommenting this will mean that you can only reach Home Assistant using the proxy, not directly via IP from other clients.
  # server_host: 127.0.0.1
  use_x_forwarded_for: true
  # You must set the trusted proxy IP address so that Home Assistant will properly accept connections
  # Set this to your NGINX machine IP, or localhost if hosted on the same machine.
  trusted_proxies:
    - 172.30.32.0/23 <use big submask for NGINX IP address here to avoid issues when the docker network changes>
```

_Based on blueprint for new add-ons._

https://github.com/home-assistant/addons-example/blob/main/example/README.md

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

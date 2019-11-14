# Docker Image for Unbound DNS Cache server

## Features
- DNS Caching using Unbound - unbound.net
- Block ad hosts from https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
- Cron job to update blocked ad hosts every day at 3 AM.
- Support for custom script execution (/app-config)

## How to use

```
docker run -itd --name unbound \
    -p 53:53 \
satishweb/unbound
```

## Docker Stack configuration:
```
services:
  unbound:
    image: satishweb/docker-unbound
    hostname: unbound
    networks:
      - default
    environment:
      DEBUG: "0"
    volumes:
      # - ./unbound-server.conf:/etc/unbound/unbound.conf.d/unbound-server.conf
      # Mount app-config script with your customizations
      # - ./app-config:/app-config
      # We need to preserve the root.key that was created by first launch
      - ./data/unbound/var-lib-unbound:/var/lib/unbound
    deploy:
      replicas: 1
      # placement:
      #   constraints:
      #     - node.labels.type == worker
      restart_policy: *default-restart-policy
    labels:
      - "com.satishweb.description=Unbound DNS Cache Service"
```
>Note: For complete services stack please visit: TBA

## Build Docker image
```
docker build . --no-cache -t docker-unbound
```
## Pull Docker Hub Image
```
docker pull satishweb/unbound
```

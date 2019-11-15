# Docker Image for Unbound DNS Cache server

## Features
- DNS Caching using Unbound - unbound.net
- Block ad hosts listed in https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
- Cron job to update blocked ad hosts daily.
- Support for custom script execution (/app-config)

## How to use

```
docker run -itd --name unbound \
    -p 53:53/tcp \
    -p 53:53/udp \
satishweb/unbound
```

## Docker Stack configuration:
```
services:
  unbound:
    image: satishweb/unbound
    hostname: unbound
    networks:
      - default
    environment:
      DEBUG: "0"
    volumes:
      # - ./unbound.conf:/etc/unbound/unbound.conf # For custom config
      # Mount app-config script with your customizations
      # - ./app-config:/app-config
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
docker build . --no-cache -t satishweb/unbound
```
## Pull Docker Hub Image
```
docker pull satishweb/unbound
```

## Credits
- AD Block Hosts: https://github.com/StevenBlack/hosts
- Unbound: http://www.unbound.net
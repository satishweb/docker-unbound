# Docker Image for Unbound DNS Cache server (Works for Raspberry PI)

## Features
- DNS Caching using Unbound - unbound.net
- Block ad hosts listed in https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
- Cron job to update blocked ad hosts daily.
- Support for custom script execution (/app-config)
- Support for linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
- Alpine based tiny images

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
      # DOMAIN_WHITELIST: "domain1.com domain2.com subdomain.domain3.com"
    volumes:
      # - ./unbound.conf:/etc/unbound/unbound.conf # For custom config
      # Mount app-config script with your customizations
      # - ./app-config:/app-config
    deploy:
      replicas: 1
      # placement:
      #   constraints:
      #     - node.labels.type == worker
    labels:
      - "com.satishweb.description=Unbound DNS Cache Service"
```

# How to setup DOH Server on Linux/Mac/RaspberryPI in minutes:
## Using Docker Compose
### Requirements:
- RaspeberryPi/Linux/Mac with Docker preinstalled (Required)
- DNS Server Setup on AWS R53 (Other providers supported)
- AWS Access Key, Secret key and R53 DNS Hosted Zone ID (for LetsEncrypt based auto installation of SSL Certs) (Optional)

### Steps
- Visit https://github.com/satishweb/docker-doh/releases and download latest release to your server
```bash
wget https://github.com/satishweb/docker-doh/archive/v2.2.4-1.zip
unzip v2.2.4-1.zip
cp -rf docker-doh-2.2.4-1/examples/docker-compose-doh-server doh-server
rm -rf v2.2.4-1.zip docker-doh-2.2.4-1
cd doh-server
```
- Copy env.sample.conf to env.conf and update environment variables
```bash
EMAIL=user@example.com
DOMAIN=example.com
SUBDOMAIN=dns
AWS_ACCESS_KEY_ID=AKIKJ_CHANGE_ME_FKGAFVA
AWS_SECRET_ACCESS_KEY=Nx3yKjujG8kjj_CHANGE_ME_Z/FnMjhfJHFvEMRY3
AWS_REGION=us-east-1
AWS_HOSTED_ZONE_ID=Z268_CHANGE_ME_IQT2CE6
DOMAIN_WHITELIST="domain1.com domain2.com subdomain.domain3.com"
```
- Launch services
```bash
./launch.sh
```
- Add your custom hosts to override DNS records if needed.
```bash
mkdir -p data/unbound/custom
vi data/unbound/custom/custom.hosts
Contents:
local-zone: "SUB1.example.com" redirect
local-data: "SUB1.example.com A 192.168.0.100"
local-zone: "SUB2.example.com" redirect
local-data: "SUB2.example.com A 192.168.0.101"
```

- What is my DOH address?
```bash
https://dns.example.com/getnsrecord
```

- How do I test DoH Server?
```bash
curl -w '\n' 'https://dns.example.com/getnsrecord?name=google.com&type=A'
```

## Common Issues and how to debug them
- Proxy is still running with self signed certificate
  - Check data/proxy/certs/acme.json contents.
  - Enable debug mode for proxy by editing proxy service in docker-compose.yml. Run launch command again for changes to take effect.
  - Check proxy container logs for errors.

> Note: If you are using IAM account for R53 access, please make sure you have below permissions added in access policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "route53:GetChange",
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*",
        "arn:aws:route53:::change/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```
- Can not bind 53 port for unbound service
  - Unbound service is configured to bind 53 port on the docker host.
  - Sometimes systemd-resolved service blocks that port and it needs to be stopped
  - run `sudo service systemd-resolved stop;sudo apt-get -y purge systemd-resolved` and then retry again
  - Unbound service port mappings can be commented out if DOH service is the only DNS client for it.

- Can not bind port 80 and 443 for proxy service.
  - Another program on the docker host or one of the docker container has aquired the same ports.
  - You need to stop those programs or change the proxy service ports to unused ports

## IPV6 Support
- Docker compose configuration with IPV6 support will be added in future.

# How to use DOH Server?
## Setup your Router (Best experience)
- Login to your router and search for DHCP settings
- Setup DNS settings to the IP of your DOH server.
> Note: This will make all your client systems/phones connected to your router use this your DNS server.
> Note: This will not make clients use DOH but it will end up using unbound private DNS service that protects you from ISP.

## Linux, Mac, Windows Clients
- Install Cloudflared for Linux, Mac, Windows using below link
```bash
https://developers.cloudflare.com/argo-tunnel/downloads/
```
- Set your DOH server as upstream for cloudflared with below configuration
  - Linux: /usr/local/etc/cloudflared/config.yml
  - Mac: /usr/local/etc/cloudflared/config.yaml
  - Windows: Need help here, if you know where to configure, please contribute

```yaml
proxy-dns: true
proxy-dns-upstream:
 - https://dns.example.com/getnsrecord
```
> Note: You will need to ensure dnsmasq is uninstalled from your client system before using cloudflared

## Android
- Install Infra app from Play Store
```bash
https://play.google.com/store/apps/details?id=app.intra&hl=en_US
```

- Configure infra app to use your DOH server
```
Infra App -> Settings -> Select DNS over HTTPS Server -> Custom server URL
Value: https://dns.example.com/getnsrecord
```

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

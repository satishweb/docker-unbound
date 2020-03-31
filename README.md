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

## How to setup DOH Server on Linux/Mac/RaspberryPI in minutes:
### Requirements
- RaspeberryPi/Linux/Mac with Docker preinstalled (Required)
- DNS Server Setup on AWS R53 (Optional)
- AWS Access Key, Secret key and R53 DNS Hosted Zone ID (for LetsEncrypt based auto installation of SSL Certs) (Optional)
- SSL Certificate (Required if your domain DNS hosting is not done at AWS)

### Steps
- Visit https://github.com/satishweb/docker-doh/releases and download latest release to your server
```
wget https://github.com/satishweb/docker-doh/archive/v2.2.1.zip
unzip v2.2.1.zip
cp -rf docker-doh-2.2.1/examples/docker-swarm-doh-server doh-server
rm -rf v2.2.1.zip docker-doh-2.2.1
cd doh-server
```
- Edit services/cert-manager/docker-service.yml and update below variables
> Note: This is to be done only if you intend to automatically setup SSL certificate using AWS DNS Hosting
```
DOMAIN_1
CERTBOT_EMAIL
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
AWS_HOSTED_ZONE_ID
```
- If you do not have AWS DNS Hosting, you need to add your SSL certificate manually
> Note: You need your SSL certificate, CA Certificates and Private Key to complete below SSL configuration. You may use letsencrypt to generate a free certificate.
```
mkdir -p data/proxy/certs
# Generate Certificate Chain using below command
cat your-ssl-certicate.pem your-ca-certificate.pem your-private-key.pem > data/proxy/certs/YOURDOMAIN.COM.combined.pem
```
- Add your custom hosts to override DNS records if needed.
> Note: This is optional unless you have certain DNS records that needs to be resolved/overridden locally.
```
mkdir -p data/unbound
vi data/unbound/custom.hosts
```
  - File Path: `data/unbound/custom.hosts`
  - File Contents Format:
```
local-zone: "SUB1.YOURDOMAIN.COM" redirect
local-data: "SUB1.YOURDOMAIN.COM A 192.168.0.100"
local-zone: "SUB2.YOURDOMAIN.COM" redirect
local-data: "SUB2.YOURDOMAIN.COM A 192.168.0.101"
```
- Start DNS server with Auto SSL Cert generation using LetsEncrypt and AWS DNS Hosting
```
./launch.sh unbound cert-manager proxy swarm-listener doh-server
```
- Start DNS Server with custom SSL certificate
```
./launch.sh unbound proxy swarm-listener doh-server
```
- Stop DNS Server:
> Note: This will remove services but does not delete data
```
./remove.sh
```
- How to check if all is running well?
> Note: Check if all services are launched successfully
```
docker service ls
```
- How to see logs of service?
```
docker service logs -f dns_unbound
```
- What is my DOH address?
> Note: This is your server DNS name that you set up
```
https://dns.YOURDOMAIN.COM/getnsrecord
```

## How to use DOH Server?
### Setup your Router (Best experience)
- Login to your router and search for DHCP settings
- Setup DNS settings to the IP of your DOH server.
> Note: This will make all your client systems/phones connected to your router use this your DNS server.
> Note: This will not make clients use DOH but it will end up using unbound private DNS service that protects you from ISP.

### Linux, Mac, Windows Clients
- Install Cloudflared for Linux, Mac, Windows using below link
```
https://developers.cloudflare.com/argo-tunnel/downloads/
```
- Set your DOH server as upstream for cloudflared with below configuration
  - Linux: /usr/local/etc/cloudflared/config.yml
  - Mac: /usr/local/etc/cloudflared/config.yaml
  - Windows: God knows where, I dont have windows!
```
proxy-dns: true
proxy-dns-upstream:
 - https://dns.YOURDOMAIN.COM/getnsrecord
```
> Note: You will need to ensure dnsmasq is uninstalled from your client system before using cloudflared

### Android
- Install Infra app from Play Store
```
https://play.google.com/store/apps/details?id=app.intra&hl=en_US
```
- Configure infra app to use your DOH server
```
Infra App -> Settings -> Select DNS over HTTPS Server -> Custom server URL
Value: https://dns.YOURDOMAIN.COM/getnsrecord

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
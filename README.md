# certbot-controller (beta)
## What is certbot?
In short, [certbot](https://github.com/certbot/certbot) is a tool that automates the process of acquiring and renewing SSL/TLS certificates from the CA/Third Party [Let's Encrypt](https://letsencrypt.org/). Not to put works in certbots mouth, so I quote:

[certbot](https://github.com/certbot/certbot), _"Certbot is part of EFF’s effort to encrypt the entire Internet. Secure communication over the Web relies on HTTPS, which requires the use of a digital certificate that lets browsers verify the identity of web servers (e.g., is that really google.com?). Web servers obtain their certificates from trusted third parties called certificate authorities (CAs). Certbot is an easy-to-use client that fetches a certificate from Let’s Encrypt—an open certificate authority launched by the EFF, Mozilla, and others—and deploys it to a web server._

_Anyone who has gone through the trouble of setting up a secure website knows what a hassle getting and maintaining a certificate is. Certbot and Let’s Encrypt can automate away the pain and let you turn on and manage HTTPS with simple commands. Using Certbot and Let's Encrypt is free."_

## What does certbot-controller do?
Certbot-controller is built on top of [certbot](https://github.com/certbot/certbot) docker image and provides additional functionality to enhance the certbot docker experience, including:

* Certbot execution using non-root user
* Customize ID mapping to the containers internal user
* Added or updated tools such as bash, openssl, openssh, etc.
* Optional plugin install using the official certbot plugins
* Optional custom plugin install
* The ability to install more than one plugin for a single docker instance
* Optional “always up” with certbots recommended cron configuration for renewals
* Optional custom cronjob scheduling for certbot renewal
* Optional custom cronjob sleep random maximum for certbot renewal
* Optional custom renewal syntax
* Optional run on start
* Optional deployment hook to transfer certificates to remote servers, using SCP
* Optional deployment hook to create pfx files
* Improved verbose log output and cron schedule output
 


## Certbot-controller: future development
The core functionality is complete and added quality of life improvements will be added over time.  This includes:

* Docker image deployment (in progress)
* CI/CD implementation for rolling updates from certbot (in progress)
* Add functionality into certbot-controller.yaml to:
  * Create Certificates
  * Add setting currently as defined as environmental variables
* Email notifications for conditions such as expiration warnings, renewals and failures
* Triggers for external services
* Docker integration for routine management
* Web UI for certificate management and monitoring

# Usage
Certbot-controller intentionally operates as close to certbot’s docker image as possible, however it includes required operations, such as non-root, ID mapping and plugin install. To run as “always up” using cron scheduling or include renewal-hooks, they need enabling.

### Unsolicited Advice
If this is the first time using certbot, I would recommend creating a certificate in letsencrypts staging environment first, by adding ‘--staging’ to the command syntax.  Certbots public services will throttle duplicate certificates of the same name, limited to 5 certificates over a 7 day period. 

When multiple certificates of the same name are created certbot will add a ‘-0000’ suffix. It can therefore help to name some certificates using, for example, ‘--cert-name subdomain.domain.tld-staging’.

## Environmental Variables

| Env | Default | Example | Function |
| --- | --- | --- | --- |
| PUID | 911 | 1000 | Sets the numeric user ID that certbot will run as within the container. This will map the host storage permissions to the guest container. |
| PGID | 911 | 1000 | Sets the numeric group ID that certbot will run as within the container. This will map the host storage permissions to the guest container. |
| CERTBOT_PLUGINS | none | certbot_dns_cloudflare | Installs offical certbot plugins from certbots github repository. |
| HOOK_INSTALL | false | true | Installs renew-hooks packaged with certbot-controller. |
| CERTBOT_RENEW_RUNONSTART | false | true | Runs renewal when the container starts. |
| CERTBOT_RENEW_SYNTAX | none | `--deploy /config/hook.sh` | Extra syntax, for when 'certbot renew' is executed. |
| CERTBOT_RENEW_CRON | false | true | Enables cron scheduling and the container will not exit after execution. |
| CERTBOT_RENEW_CRON_SCHEDULE | `0 */12 * * *` (every 12th hour) | `*/5 * * * *` | Set [crontab](https://man7.org/linux/man-pages/man5/crontab.5.html) schedule to a custom value. |
| CERTBOT_RENEW_CRON_MAX_SLEEPTIME | 43199 (12 hours) | 3600 | A sleep period is added to the cronjob and randomises the execution to prevent throttling 'Let's Encrypt' servers.  It can be disabled for testing with 0, however this isn't recommended. |

## Certbot Official Plugins
Offical plugins are installed by download from certbot's github repository.  Default plugin names can be found in certbot's github using there directory or release name (kebab-case "-" or "_" are both accepted). For Example cloudflare's name is "certbot-dns-cloudflare" so the plugin name is "certbot-dns-cloudflare" or "certbot_dns_cloudflare".  All default plugins much be available as an asset in there releases.

## Custom Plugins
Custom plugins can be installed by placing them, uncompressed, in a folder within '/config/plugins/' for example '/config/plugins/name-of-plugin/'. There must have a 'setup.py' file within this directory, for them to install correctly.

## Certbot-Controller Renew Options
Renewal's can operate as the stock docker image by command using "renew" after certificates have been created. However certbot-controller adds environmental variable **'CERTBOT_RENEW_RUNONSTART'** that will run renewal when the container starts. When finished it will exit, unless **'CERTBOT_RENEW_CRON'** is true, which will enable the cron services using certbot recommended configuration.  The **'CERTBOT_RENEW_SYNTAX'** option adds additional syntax for the renewal command, for example `--deploy /config/hook.sh`.

## Certbot-Controller Cronjob Options
The default and certbots recommended cron schedule is `0 */12 * * *` with a random sleep between 0 and 43,199 functionally a 24 hour period. Cronjob customizations are defined using **'CERTBOT_RENEW_CRON_SCHEDULE'** and **'CERTBOT_RENEW_CRON_MAX_SLEEPTIME'**. For scheduling [crontab guru](https://crontab.guru/) is a good resource.  Sleep periods are always between 0 and a maximum, hence a max sleeptime option. This randomness prevent throttling 'Let's Encrypt' servers on the 12th hours.  It can however be disabled when set to 0.

## Certbot-Controller  Renewal Hooks
Renewal Hooks are scripts that execute on renewal of a certificate.  They automate common tasks such as creating PFX files or deploying the certificates. For more information on hooks see the following [certbot documentation](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates).

Packaged with certbot-controller are the following hooks, however they are not installed by default, they are enabled by setting **'HOOK_INSTALL'** to true.

* Deploy certificate files via SCP to remote servers
* Create PFX certificate files

### Configuration
All hooks configuration are located in `\config\certbot-controller.yaml`.

```YAML
hooks:
  connections:
    - name: webserver # link from connection names for example scp.connection
      host: ip address # hostnames or ip address
      remote-user: username
      ssh-keyfile: username-webserver # Default location /config/.ssh
    - name: waf  # Names link to connection names for example scp.connection
      host: hostname # hostnames or ip address
      remote-user: username
      ssh-keyfile: /config/.ssh/username-hostname # direct paths
      timeout: 5 # Optional timeout, default 15 seconds
  deploy:
    scp:
      - connection: waf # links via the connection name in hooks.connections
        certificates:
          - name: subdomain.domain.tld
            path: /path/on/remote/host/ssl/subdomain.domain.tld
            files:
              - fullchain.pem
              - privkey.pem
          - name: domain.tld
            path: /path/on/remote/host/ssl/domain.tld
            files:
              - domain_tld.pfx
      - connection: webserver # links via the connection name in hooks.connections
        certificates:
          - name: domain.tld
            path: /path/on/remote/host/ssl/domain.tld
            files:
              - fullchain.pem
              - privkey.pem
    pfx:
      certificates:
        - name: subdomain.domain.tld
          password: super-secret-password #optional, default is the file name without extension

```


## Certbot-Controller Logging

Log outputs are verbose, therefore executing `certbot container-name logs` will display previous executions and schedule of the next run.  For more information when debugging plugins, set **'CERTBOT_PLUGIN_DEBUG'** to true.


# Examples

## Creating a Certificate
Certificates are currently created using certbot command method.  For example:
#### docker cli:
```bash
docker run -it \
  --rm \
  --name certbot-controller-run \
  -e PGID=1000 \
  -e PUID=1000 \
  -e CERTBOT_PLUGINS=certbot_dns_cloudflare \
  -v "./config:/config" \
  -v "./etc/letsencrypt:/etc/letsencrypt" \
  -v "./var/log/letsencrypt:/var/log/letsencrypt" \
  certbot-controller:v5.7.0-1 \
  certonly --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30 \
    --email admin@domain.tld \
    --agree-tos \
    --no-eff-email \
    --rsa-key-size 4096 \
    --keep-until-expiring \
    -d subdomain.domain.tld
```

#### docker compose
```yaml
services:
  certbot-controller:
    image: certbot-controller:v5.7.0-1
    container_name: certbot-controller
    environment:
      PUID: 1000
      PGID: 1000
      CERTBOT_PLUGINS: >-
        certbot_dns_cloudflare
    volumes:
      - ./config:/config
      - ./etc/letsencrypt:/etc/letsencrypt
      - ./var/log/letsencrypt:/var/log/letsencrypt
    command: >-
      certonly --dns-cloudflare
        --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini
        --dns-cloudflare-propagation-seconds 30
        --email admin@domain.tld
        --agree-tos
        --no-eff-email
        --rsa-key-size 4096
        --keep-until-expiring
        -d subdomain.domain.tld
```
*Note: When using docker compose to create certificates, I would recommend using a separate compose file for the renewals or removing the command, once executed.*

## Cron Scheduling
Enable cron scheduling with certbot defaults and a single plugin `certbot_dns_cloudflare`.

#### docker cli
```bash
docker run -it \
  --rm \
  --name certbot-controller-run \
  -e PGID=1000 \
  -e PUID=1000 \
  -e CERTBOT_PLUGINS=certbot_dns_cloudflare \
  -e CERTBOT_RENEW_CRON=true \
  -v "./config:/config" \
  -v "./etc/letsencrypt:/etc/letsencrypt" \
  -v "./var/log/letsencrypt:/var/log/letsencrypt" \
  certbot-controller:v5.7.0-1
```

#### docker compose
```yaml
services:
  certbot-controller:
    image: certbot-controller:v5.7.0-1
    container_name: certbot-controller
    environment:
      PUID: 1000
      PGID: 1000
      CERTBOT_PLUGINS: >-
        Certbot_dns_cloudflare
      CERTBOT_RENEW_CRON: true
    volumes:
      - ./config:/config
      - ./etc/letsencrypt:/etc/letsencrypt
      - ./var/log/letsencrypt:/var/log/letsencrypt
```


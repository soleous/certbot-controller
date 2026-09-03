# certbot-controller (beta)
## What is certbot?
In summary, [certbot](https://github.com/certbot/certbot) is a tool that automates the process of acquiring and renewing SSL/TLS certificates from the CA/Third Party [Let's Encrypt](https://letsencrypt.org/). Not to put works in certbot's mouth, so to quote:

[certbot](https://github.com/certbot/certbot), _"Certbot is part of EFF’s effort to encrypt the entire Internet. Secure communication over the Web relies on HTTPS, which requires the use of a digital certificate that lets browsers verify the identity of web servers (e.g., is that really google.com?). Web servers obtain their certificates from trusted third parties called certificate authorities (CAs). Certbot is an easy-to-use client that fetches a certificate from Let’s Encrypt—an open certificate authority launched by the EFF, Mozilla, and others—and deploys it to a web server._

_Anyone who has gone through the trouble of setting up a secure website knows what a hassle getting and maintaining a certificate is. Certbot and Let’s Encrypt can automate away the pain and let you turn on and manage HTTPS with simple commands. Using Certbot and Let's Encrypt is free."_

## What does certbot-controller do?
Certbot-controller is built on top of the '[certbot](https://github.com/certbot/certbot) docker image' and provides additional functionality to enhance the certbot docker experience, including:

* Designed as "over the top service" for certbot’s existing docker image and therefore workflows
* By default, certbot executes as a non-root user
* Customize non-root user/group IDs for the containers internal user
* Added or updated tools such as bash, openssl, openssh, etc.
* Optional:
  * Install official certbot plugins, sourced from certbot
  * Install custom plugins from other sources
  * Scheduled certificate renewal using certbot's recommended configuration
  * Customize certbot's renewal schedule (including random sleep periods)
  * Certificate renewal on container start
  * Renew automation (renewal-hooks) to:
    * Transfer certificates to remote servers, using SCP
    * Create pfx files
* Install more than one plugin on a single docker instance
* Improved verbose log output and next schedule output

## Certbot-controller: future development
The core functionality is complete and added quality of life improvements will be done over time.  This may includes:

* Docker image deployment (in progress)
* CI/CD implementation for rolling updates from certbot (in progress)
* Improve certificate creation workflows
* Add methods to automate ssh key creation
* Renew automation (renewal-hook) to change permissions, owners and groups
* Renew automation (renewal-hook) for local transfer
* Expose configuration outside of environmental variables
* Email notifications for conditions such as expiration warnings, renewals and failures
* Triggers for external services
* Docker integration for renew automation (renewal-hook)
* Web UI for certificate management and monitoring

# Usage
Certbot-controller is designed to operate as close to certbot’s docker image as possible, however non-root configuration and extra tools are an operational requirement. The majority of features are optional, including, “always up” cron scheduling, packaged renewal-hooks, plugin installs, etc. By design this should swap into existing workflows, with the exception of running as root.

### Unsolicited Advice
If this is the first time using certbot, I would recommend creating a certificate in Let's Encrypt's staging environment first, by adding ‘--staging’ to the command syntax.  Certbot's public services will throttle duplicate certificates of the same name, limited to 5 certificates over a 7 day period. 

When multiple certificates of the same name are created certbot will add a ‘-0000’ suffix. It can therefore help to name some certificates using, for example, ‘--cert-name subdomain.domain.tld-staging’.

## Environmental Variables

| Env | Default | Example | Function |
| --- | --- | --- | --- |
| PUID | 911 | 1000 | Sets the numeric user ID that certbot will run as within the container. This will map the host storage permissions to the guest container. |
| PGID | 911 | 1000 | Sets the numeric group ID that certbot will run as within the container. This will map the host storage permissions to the guest container. |
| CERTBOT_PLUGINS | none | `certbot_dns_cloudflare` | Installs official certbot plugins from certbot's github repository. |
| CERTBOT_PLUGIN_DEBUG | false | true | Output 'plugin install' debugs logs to `/config/logs/plugin-install` |
| HOOK_INSTALL | false | true | Installs renew-hooks packaged with certbot-controller. |
| CERTBOT_RENEW_RUNONSTART | false | true | Runs renewal when the container starts. |
| CERTBOT_RENEW_SYNTAX | none | `--deploy /config/hook.sh` | Extra syntax, for when 'certbot renew' is executed. |
| CERTBOT_RENEW_CRON | false | true | Enables cron scheduling and the container will not exit after execution. |
| CERTBOT_RENEW_CRON_SCHEDULE | `0 */12 * * *` (every 12th hour) | `0 0 * * *` | Set [crontab](https://man7.org/linux/man-pages/man5/crontab.5.html) schedule to a custom value. **Not recommended** |
| CERTBOT_RENEW_CRON_MAX_SLEEPTIME | 43199 (12 hours) | 86400 | A sleep period (in seconds) is added to the cronjob and randomizes the execution to prevent throttling 'Let's Encrypt' servers.  It can be disabled for testing with 0. **Not recommended** |

## Certbot Official Plugins
Official plugins are installed by download from certbot's github repository.  Default plugin names can be found in certbot's github using their directory or release name (kebab-case "-" or "_" are both accepted). For Example cloudflare's name is "certbot-dns-cloudflare" so the plugin name is "certbot-dns-cloudflare" or "certbot_dns_cloudflare".  All default plugins must be available as an asset in their releases.

For more information when debugging plugins, set **'CERTBOT_PLUGIN_DEBUG'** to 'true' and debug logs will be stored in `/config/logs/plugin-install`.

## Custom Plugins
Custom plugins can be installed by placing them, uncompressed, in a folder within '/config/plugins/' for example '/config/plugins/name-of-plugin/'. There must be a 'setup.py' file within this directory, for them to install correctly.  

For more information when debugging plugins, set **'CERTBOT_PLUGIN_DEBUG'** to 'true' and debug logs will be stored in `/config/logs/plugin-install`.

## Certbot-Controller Renew Options
Renewal's can operate as the stock docker image by command using "renew" after certificates have been created. However certbot-controller adds environmental variable **'CERTBOT_RENEW_RUNONSTART'** that will run renewal when the container starts. When finished it will exit, unless **'CERTBOT_RENEW_CRON'** is 'true', which will enable the cron services using certbot recommended configuration.  The **'CERTBOT_RENEW_SYNTAX'** variable adds additional syntax for the renewal command, for example `--deploy /config/hook.sh`.

## Certbot-Controller Renew Schedule/Cron
Certbot-Controller's default and certbot's recommended cron schedule is `0 */12 * * *` (the 12th hour) with a random sleep between 0 and 43,199 (12 Hours), functionally executing randomly in a 12 hour period. 

Although **not recommended** (see below tip), Cronjob customization are defined using **'CERTBOT_RENEW_CRON_SCHEDULE'** and **'CERTBOT_RENEW_CRON_MAX_SLEEPTIME'**. For scheduling [crontab guru](https://crontab.guru/) is a good resource.  Sleep periods are always between 0 and a maximum, hence a max sleeptime variable. This randomness prevents throttling 'Let's Encrypt' servers on an exact schedule.  It can however be disabled when set to 0.

> [!TIP]
> Sleep periods should coincide within the schedule period. As cron executes at the scheduled time, the renew process will wait (sleep) to execute. If your sleep is past the next scheduled run, you will get odd results within your schedule. For example, if you schedule every 5 minutes and sleep for 12 hours, renew will not execute every 5 minutes, but create a run job every 5 minutes and they will all execute randomly over a 12 hour period.  Settings like this can throttle the Let's Encrypt servers and block you from renewing certificates, hency why its **not recommended**, it's not just to prevent throttling on scheduled times.
>
> However, if you wise to execute, for example, at 4am with an random sleep of 1 hour, creating a more routine maintenance windows.  This can be done using a schedule of `0 4 * * *` and sleep `3600`.
>
> Use at your own risk and please respect Let's Encrypt servers.

## Certbot-Controller Renewal Hooks
Renewal Hooks are scripts that execute on renewal of a certificate.  They automate common tasks such as creating PFX files or deploying the certificates. For more information on hooks see the following [certbot documentation](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates).

Packaged with certbot-controller are the following hooks, however they are not installed by default, they are enabled by setting **'HOOK_INSTALL'** to 'true'.

* Deploy certificate files via SCP to remote servers
* Create PFX certificate files

### Configuration
All hook configurations are located in `\config\certbot-controller.yaml`.

```YAML
hooks:
  connections: # these are the remote connections used by other processes such as scp
    - name: webserver # link from connection names for example scp.connection
      host: ip address # hostnames or ip address
      remote-user: username
      ssh-keyfile: ssh-key-file-name # ssh keys for ssh/scp with default location /config/.ssh
    - name: waf  # Names link to connection names for example scp.connection
      host: hostname # hostnames or ip address
      remote-user: username
      ssh-keyfile: /config/.ssh/ssh-key-file-name # ssh keys for ssh/scp with direct paths
      timeout: 5 # Optional timeout, default 15 seconds
  deploy:
    scp: # this section has configuration to scp files to remote connections
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
      certificates: # only certificates in this section will have a PFX file created
        - name: subdomain.domain.tld
          password: super-secret-password #optional, default is the file name without extension

```
If a hook requires configuration, it can be entered in the above file using yaml. Configuration can link to different yaml blocks, for example scp connections, link to the connections block. If you do not require for example pfx file creation, this section can be deleted from your yaml file.

Certificate names are defined by certbot and executing the command `certificates` will display all current certificates and their state.

### Testing Renewal-hook Outside of the Renewal Process
If a script errors or fails while renewing, they can be debugged, tested or rerun outside of the renewal process by directly executing the script. For example from cli:

```bash
docker exec -it certbot-controller /scripts/letsencrypt/renewal-hooks/deploy/<script>.sh --cert-name subdomain.domain.tld
```

Alternatively, shell into the container using bash `docker exec -it certbot-controller /bin/bash` and execute the scripts located in the scripts folder.

Lastly, current versions of the scripts are displayed using `--version`.

> [!NOTE]
> * All uninstalled scripts are stored under: `/scripts/letsencrypt/renewal-hooks/`, `pre`, `post` and `deploy`
> * All installed scripts are stored under: `/etc/letsencrypt/renewal-hooks/`, `pre`, `post` and `deploy`

> [!IMPORTANT]
> Shelling into the docker container using this method will be run as `root`, so if permissions are incorrect, it will be a false positive. It is also not recommended to create/renew certificates using this method, because it can break permissions on certificate files.

### Creating SSH Keys
If the renewal-hook script requires ssh keys, the following is a brief description on how to create them:

#### Executed on client/certbot-controller Linux host
```bash
ssh-keygen -t rsa -C "username@certbot-controller" -f config/.ssh/username-remotename
cat config/.ssh/username-remotename.pub
```
#### Add the public key to the remote server for example in Linux
```bash
mkdir ~/.ssh
vi ~/.ssh/authorized_keys
```
> [!TIP]
> The ssh keys should be added to the correct user on the remote server.

#### Validate the ssh keys
the following should connect successfully without requiring a password.
```bash
ssh -i config/.ssh/username-remotename username@server
```

## Certbot-Controller Logging
Log outputs are verbose, therefore executing `certbot logs container-name` will display container history and current certificate renewals, including schedule of the next run.

# ID Mapping, Security and Certificate Deployment
Within certbot-controller, certbot is executed using user and group IDs (default 911), they can be customized using variable **'PUID'** and **'PGID'**. All files within `/config`, `/etc/letsencrypt` and `var/log/letsencrypt` will therefore use the same IDs.

Certbot certificate file permissions can be shown by executing `ls -l etc/letsencrypt/archive/subdomain.domain.tld/` and by default the owner has 'read/write' for private keys and public keys. Groups and others get 'read' only for public keys. When deploying these certificates manually permissions may need to be changed to allow other applications to read them.

### Renewal-hook: SCP

When using the SCP renewal-hook, files are transferred using the **remote user** and therefore **permissions** on the **remote host**.  If this **remote user** does not have correct permissions to the file, expect a `Permission denied`.

To configure correct permissions on the remote host, there are several options, however, for security reasons, the following is recommended:
* Do not use a high privileged user for example root or critical services owner
* Create a user specifically for certificate management/transfer and only give it permissions to files its transferring
* Shared access between applications and containers via groups and make the user a member
* Set permissions at a minimal, file permissions are not changed on the remote server when transferring files

> [!CAUTION]
> Use at your own risk, the biggest recommendation is to understand your architecture and assess the risks of your configuration.  We take no liability.


### Renewal-hook: PFX
PFX files are created for specific domains only. The default password is weak, as it's documented here, being the file name without suffix, it's recommended to set a password.

PFX file permissions are by default 'read/write' for users and groups, others have none.

# Examples

## Docker Images
Currently there are no official Docker images as the CI/CD is in development.  To build an image for testing, use the following docker build command.

```bash
docker buildx build \
  --tag certbot-controller:v5.7.0-1 \
  --label certbot-controller_build=1 \
  --build-arg CERTBOT_IMAGE_TAG="v5.7.0"
```


## Creating a Certificate
If you don't already have certificates, the main method is currently to use a certbot command.  For example:
#### docker cli:
```bash
docker run -it --rm \
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
> [!TIP]
> When using docker compose to create certificates, I would recommend using a separate compose file for the renewals, removing the command (once executed) or executing docker compose with `rm` to remove stopped services.

## Renewal Scheduling
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

## Fully Stack Docker Compose/Template
The following example is a complete template including all environment variables and create certificate command "remarked out".
```yaml
services:
  certbot-controller:
    image: certbot-controller:v5.7.0-1
    container_name: certbot-controller
    #environment:
      #PUID: 1000
      #PGID: 1000
      #CERTBOT_PLUGINS: >-
      #  certbot_dns_cloudflare
      #  certbot-dns-route53
      #CERTBOT_PLUGIN_DEBUG: true #plugin install debug logs: /config/logs/
      #CERTBOT_RENEW_SYNTAX: '--deploy-hook /path/to/renewal-hooks/filename.sh'
      #CERTBOT_RENEW_RUNONSTART: true #enable run on container start
      #CERTBOT_RENEW_CRON: true #enable cron
      #CERTBOT_RENEW_CRON_SCHEDULE: '0 4 * * *' #schedule at 4am
      #CERTBOT_RENEW_CRON_MAX_SLEEPTIME: 21600 #6 hours in seconds, disable using 0 (not recommended) 
      #HOOK_INSTALL: true #enables the hook deployments/installs
    volumes:
      - ./config:/config
      - ./etc/letsencrypt:/etc/letsencrypt
      - ./var/log/letsencrypt:/var/log/letsencrypt
    #command: >-
    #  certonly --dns-cloudflare
    #    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini
    #    --dns-cloudflare-propagation-seconds 30
    #    --email admin@domain.tld
    #    --agree-tos
    #    --no-eff-email
    #    --rsa-key-size 4096
    #    --keep-until-expiring
    #    -d subdomain.domain.tld
    #    --cert-name subdomain.domain.tld
```
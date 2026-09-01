# certbot-controller (beta)
## What is certbot?
For people who have stumbled across this github…

[certbot](https://github.com/certbot/certbot), _"Certbot is part of EFF’s effort to encrypt the entire Internet. Secure communication over the Web relies on HTTPS, which requires the use of a digital certificate that lets browsers verify the identity of web servers (e.g., is that really google.com?). Web servers obtain their certificates from trusted third parties called certificate authorities (CAs). Certbot is an easy-to-use client that fetches a certificate from Let’s Encrypt—an open certificate authority launched by the EFF, Mozilla, and others—and deploys it to a web server._

_Anyone who has gone through the trouble of setting up a secure website knows what a hassle getting and maintaining a certificate is. Certbot and Let’s Encrypt can automate away the pain and let you turn on and manage HTTPS with simple commands. Using Certbot and Let's Encrypt is free."_

## What does certbot-controller do?
Certbot-controller is built on top of [certbot](https://github.com/certbot/certbot) docker image and provides additional functionality to enhance the certbot docker experience, including:

* Certbot execution using non-root user (default UID: 911, GID: 911)
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
 


## certbot-controller: future developments
This is a passion project originating from personal use of the certbot docker image and migrations to embedded platforms that are more limited. Yes, caddy, traefik, etc. now support letsencrypt certificates, but my preference is to segment this role and intended to continue refining this tool and possibly implement some of the following:

* Docker image deployment (in progress)
* Investigate options to make certificate creation easier and more manageable
* Email notifications for conditions such as expiration warnings, renewals and failures
* Triggers for external services
* Docker integration for routine management
* Web ui for certificate management and monitoring

# Usage
Certbot-controller intentionally operates as close to certbot’s docker image as possible, however it includes required operations, such as non-root, ID mapping and plugin install. To run as “always up” using cron scheduling or include renewal-hooks, they need enabling.

## Unsolicited Advice
If this is the first time using certbot, I would recommend creating a certificate in letsencrypts staging environment first, by adding ‘--staging’ to the command syntax.  Certbots public services will throttle duplicate certificates of the same name, limited to 5 certificates over a 7 day period. 

When multiple certificates of the same name are created certbot will add a ‘-0000’ suffix. It can therefore help to name some certificates using, for example, ‘--cert-name subdomain.domain.tld-staging’.

#!/bin/bash

##############################################################################
#                               entrypoint.sh                                #
##############################################################################

# This is a hook prior to the first program to launched at container start.
# Certbot's normal behaviour uses a docker ENTRYPOINT of "certbot" and CMD
# for syntax. This program creates a file of the certbot command to be
# called by the init-certbot service.

CERTBOT_COMMAND_FILE="/etc/s6-overlay/s6-rc.d/init-cmd/command"
CERTBOT_COMMAND="certbot $*"

if [[ -n $* ]] ;then
  echo "entrypoint: info: Adding certbot command to ${CERTBOT_COMMAND_FILE}: ${CERTBOT_COMMAND}"
  echo "${CERTBOT_COMMAND}" > ${CERTBOT_COMMAND_FILE}
fi

exec /init
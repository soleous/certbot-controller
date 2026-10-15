#!/bin/bash

##############################################################################
#                                  20-scp.sh                                 #
##############################################################################
#
# This script is for certbots renewal-hooks to transferring certificate files
# to other servers using SCP. It uses a YAML file for configuration and SSH 
# Keys, rather than username and password.
#
# The YAML files default location is '/config/certbot-controller.yaml',
# and all SSH keys by default are stored in '/config/.ssh', however direct
# paths can be used.
#
# Example YAML file:
# hooks:
#   connections:
#     - name: server-1
#       host: IP Address
#       remote-user: username
#       ssh-keyfile: /path/to/filename
#       timeout: custom timeout
#     - name: server-2
#       host: IP Address
#       remote-user: username
#       ssh-keyfile: filename
#   deploy:
#    scp:
#      certificates:
#        - name: subdomain.domain.tld
#          connections:
#            - name: waf
#              files:
#                - fullchain.pem
#                - privkey.pem
#              path: /path/on/remote/host/ssl/subdomain.domain.tld
#        - name: domain.tld
#          connections:
#            - name: waf
#              files:
#                - domain_tld.pfx
#              path: /path/on/remote/host/ssl/domain.tld
#            - name: webserver
#              files:
#                - fullchain.pem
#                - privkey.pem
#              path: /path/on/remote/host/ssl/domain.tld
#
# NOTE: 'deploy.scp.certificates[].connections[].name' looks up for servers within 'connections[].name'.
#
# Script Documentation: https://github.com/soleous/certbot-controller

##############################################################################
#                                 VERSIONING                                 #
##############################################################################
VERSION="2.1"
DATE="2026-10-15 21:21 UTC"
AUTHOR="Soleous (https://github.com/soleous)"

##############################################################################
#                        SCRIPT RENEWAL-HOOK TESTING                         #
##############################################################################
#
# Uncomment to simulate certbot renewal-hook execution

#RENEWED_LINEAGE="/etc/letsencrypt/live/domain.tld"
#RENEWED_DOMAINS="*.domain.tld"

#RENEWED_LINEAGE="/etc/letsencrypt/live/domain.tld-0001"
#RENEWED_DOMAINS="*.domain.tld domain.tld"

#RENEWED_LINEAGE="/etc/letsencrypt/live/subdomain.domain.tld"
#RENEWED_DOMAINS="subdomain.domain.tld"

##############################################################################
#                                    MAINS                                   #
##############################################################################

main() {
  # script functional variables
  CERTBOT_CERT_NAME=$(basename "$RENEWED_LINEAGE")

  # script default variables
  CONFIG_FILE=${CONTAINER_DIR_CONFIG}/certbot-controller.yaml
  SSH_KEY_FILE_PATH=${CONTAINER_DIR_CONFIG}/.ssh
  CONNECTION_TIMEOUT_DEFAULT=15

  # default variable override - config file
  if [[ -n "$ARG_CONFIG" ]]; then
    CONFIG_FILE=${ARG_CONFIG}
  fi

  # conditional exit if no YAML file
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    # error handling, for cli execution
    if [[ -n "$ARG_CERT_NAME" ]]; then
      echo "error: YAML file '${CONFIG_FILE}' does not exist. See documentation at 'https://github.com/soleous/certbot-controller'"
      exit 1
    else
      echo "info: YAML file '${CONFIG_FILE}' is missing"
      exit 0
    fi
  fi

  # execution info - report user, for cli execution
  if [[ -n "$ARG_CERT_NAME" ]]; then
    echo "info: executing $(basename "$0") script as '$(whoami)'"
  else
    echo "info: executing $(basename "$0") script"
  fi

  # read hooks block from certbot-controller.yaml
  HOOKS_YAML=$(yq '.hooks' ${CONFIG_FILE})

  # read connections amd Certificate to SCP for parsing
  readarray -t CONNECTIONS < <(echo "$HOOKS_YAML" | yq -o=j -I=0 '.connections' -)
  readarray -t SCP_CERT_CONNECTIONS < <(echo "$HOOKS_YAML" | CERTBOT_CERT_NAME=${CERTBOT_CERT_NAME} yq -o=j -I=0 '.deploy.scp.certificates[] | select(has("name")) | select(.name == (env(CERTBOT_CERT_NAME))) | .connections[]' -)

  # for error handling, count the amount of times an scp was found or executed
  SCP_EXEC_COUNT=0

  # for each SCP item in .deploy.scp yaml/json
  for SCP_CERT_CONNECTION in "${SCP_CERT_CONNECTIONS[@]}"; do
    # get all connection used for SCP
    CONNECTION_NAME=$(echo "$SCP_CERT_CONNECTION" | yq '.name' -)
    readarray -t SCP_CONNECTION < <(echo "$CONNECTIONS" | CONNECTION_NAME=${CONNECTION_NAME} yq ' .. | select(has("name")) | select(.name == (env(CONNECTION_NAME)))' -)

    # error handling and escape to next SCP item - quantity of connections found, should only be 1.
    if [[ ${#SCP_CONNECTION[@]} == 0 ]]; then
      echo "error: No connection found for SCP '$CONNECTION_NAME'"
      continue
    elif [[ ${#SCP_CONNECTION[@]} > 1 ]]; then
      echo "error: too many connections found for SCP '$CONNECTION_NAME'"
      continue
    fi

    # set variables for SCP connection
    REMOTE_HOST=$(echo "$SCP_CONNECTION" | yq '.host' -)
    REMOTE_USER=$(echo "$SCP_CONNECTION" | yq '.remote-user' -)
    SSH_KEYFILE=$(echo "$SCP_CONNECTION" | yq '.ssh-keyfile' -)

    # default variable - if SSH_KEYFILE value does not contain a path, use default location
    if [[ ! "$SSH_KEYFILE" =~ '/' ]]; then
       SSH_KEYFILE=${SSH_KEY_FILE_PATH}/${SSH_KEYFILE}
    fi

    # error messaging and escape to next SCP item - ssh key files does not exist
    if [[ ! -f "${SSH_KEYFILE}" ]]; then
      echo "error: failed transfer: ssh key file '${SSH_KEYFILE}' does not exist"
      continue
    fi

    # default variable override - connection timeout
    if [[ $(echo "$SCP_CONNECTION" | yq '. | has("timeout")' -) == true ]]; then
      CONNECTION_TIMEOUT=$(echo "$SCP_CONNECTION" | yq '.timeout' -)
    else
      CONNECTION_TIMEOUT=${CONNECTION_TIMEOUT_DEFAULT}
    fi

    # set variables for SCP paths
    REMOTE_PATH=$(echo "$SCP_CERT_CONNECTION" | yq '.path' -)

    echo "info: executing SCP transfer of certificate '$CERTBOT_CERT_NAME' to '${REMOTE_PATH}' on '$CONNECTION_NAME' ($REMOTE_HOST)"

    # set variables for certificate files for SCP and command execution
    readarray -t SCP_CERT_CONNECTION_FILES < <(echo "$SCP_CERT_CONNECTION" | yq '.files[]' -)
    for SCP_CERT_CONNECTION_FILE in  "${SCP_CERT_CONNECTION_FILES[@]}"; do
      # for error handling, count the amount of times an scp was found or executed
      ((SCP_EXEC_COUNT++))

      # scp file transfer execution
      echo "info: transferring file '$SCP_CERT_CONNECTION_FILE'"
      scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=${CONNECTION_TIMEOUT} -i ${SSH_KEYFILE} ${RENEWED_LINEAGE}/${SCP_CERT_CONNECTION_FILE} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}
      exiterr=$?
      if [ ${exiterr} -eq 0 ]; then
        echo "info: successfully transferred file '$SCP_CERT_CONNECTION_FILE'"
      else
        echo "error: failed transfer: exit code ${exiterr}"
      fi
    done

  done

# error handling, for cli execution
if [[ "$SCP_EXEC_COUNT" == 0 ]]; then
    if [[ -n "$ARG_CERT_NAME" ]]; then
      echo "info: no SCP configuration for certificate '$CERTBOT_CERT_NAME'. See documentation at 'https://github.com/soleous/certbot-controller'"
    else
      echo "info: no tasks to process for certificate '$CERTBOT_CERT_NAME'"
    fi
fi
}

################################### Help #####################################

help() {
  echo -e "usage:"
  echo -e "  certbot [--cert-name NAME] [options]..."
  echo -e ""
  echo -e "20-scp.sh deploys certificate files using SCP to remote servers as part of certbot's renewal hook"
  echo -e "automatons. It should be used within a certbot-controller container and configuration is stored"
  echo -e "in a yaml file. When executing manually outside of certbot renewal hooks specify the certificate"
  echo -e "using '--cert-name'."
  echo -e ""
  echo -e "create pfx files:"
  echo -e "  --cert-name NAME       Certificate to use with this script"
  echo -e ""
  echo -e "options:"
  echo -e "  --help                 show this help message and exit"
  echo -e "  --version              show script version information"
  echo -e "  --config CONFIG_FILE   path to config file (default: /config/certbot-controller.yaml)"
  echo -e ""
  echo -e "See documentation at 'https://github.com/soleous/certbot-controller' for more information."
  echo -e ""
}

################################## Version ###################################

version() {
  echo "version: $VERSION"
  echo "date: $DATE"
  echo "author: $AUTHOR"
}

##############################################################################
#                                 FUNCTIONS                                  #
##############################################################################

#################################### None ####################################


##############################################################################
#                          Pass into main functions                          #
##############################################################################

# detects if script is ran as part of certbot renewal-hook
if [ $# == 0 ]; then
  # error message for no RENEWED_LINEAGE
  if [[ -z "$RENEWED_LINEAGE" ]]; then
  echo "Error: No 'renewal lineage' from certbot renewal hook or --cert-name 'subdomain.domain-name.tld-0001' syntax. To display more help details use '--help'."
  exit 1
  fi

  # execute main script and add prefix for outputs
  main  \
    2> >(awk -v prefix="DEPLOY-HOOK-SCP:" '{ print prefix, $0 }' >&2) \
    > >(awk -v prefix="DEPLOY-HOOK-SCP:" '{ print prefix, $0 }')
else
  # script arguments for functions outside of renewal hook

  # set variables for arguments
  until [ $# == 0 ]; do
    case $1 in
      --help)
        ARG_HELP="true"
        shift
        ;;
      --version)
        ARG_VERSION="true"
        shift
        ;;
      --cert-name)
        ARG_CERT_NAME="${2}"
        shift
        ;;
      --config)
        ARG_CONFIG="${2}"
        shift
        ;;
    esac
    shift
  done

  # argument: '--help' and '--version'
  if [[ $ARG_HELP == true ]]; then
    help
    exit 0
  elif [[ $ARG_VERSION == true ]]; then
    version
    exit 0
  fi

  # argument: --cert-name
  if [[ -z "$ARG_CERT_NAME" ]]; then
    echo "Error: '--cert-name' requires a name for example: '--cert-name subdomain.domain-name.tld-0001'"
  else
    # set RENEWED_LINEAGE using argument value
    RENEWED_LINEAGE="/etc/letsencrypt/live/${ARG_CERT_NAME}"

    # execute main without prefix
    main
  fi
fi
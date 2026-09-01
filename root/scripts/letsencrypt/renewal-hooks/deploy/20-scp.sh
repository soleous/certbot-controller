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
#       ssh-keyfile: /path/to/filename # direct path
#       timeout: custom timeout # Optional
#     - name: server-2
#       host: IP Address
#       remote-user: username
#       ssh-keyfile: filename # file stored in /config/.ssh
#   deploy:
#     scp:
#       - connection: server-1
#         certificates:
#           - name: subdomain.domain.tld
#             path: /var/lib/nginx/ssl/subdomain.domain.tld
#             files:
#               - fullchain.pem
#               - privkey.pem
#           - name: subdomain2.domain.tld
#             path: /var/lib/nginx/ssl/subdomain2.domain.tld
#             files:
#               - fullchain.pem
#               - privkey.pem
#       - connection: server-2
#         certificates:
#           - name: subdomain.domain.tld-0001
#             path: /opt/lib/nginx/ssl/subdomain.domain.tld
#             files:
#               - fullchain.pem
#               - privkey.pem
#
# NOTE: 'deploy/scp/connection' looks up for servers within 'connections'.
#
# Script Documentation: https://github.com/soleous/certbot-controller

##############################################################################
#                                 VERSIONING                                 #
##############################################################################
VERSION="1.4"
DATE="2026-08-31 13:35 UTC"
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
  SCP_CONFIG_FILE=${CONTAINER_DIR_CONFIG}/certbot-controller.yaml
  SSH_KEY_FILE_PATH=${CONTAINER_DIR_CONFIG}/.ssh
  CONNECTION_TIMEOUT_DEFAULT=15

  # conditional exit if no YAML file
  if [[ ! -f "${SCP_CONFIG_FILE}" ]]; then
    # error handling, for cli execution
    if [[ -n "$ARG_CERT_NAME" ]]; then
      echo "error: YAML file '${SCP_CONFIG_FILE}' does not exist. See documentation at 'https://github.com/soleous/certbot-controller'"
      exit 1
    else
      echo "info: YAML file '${SCP_CONFIG_FILE}' is missing"
      exit 0
    fi
  fi

  echo "info: executing $(basename "$0") script"

  # read hooks block from certbot-controller.yaml
  HOOKS_YAML=$(yq '.hooks' ${SCP_CONFIG_FILE})

  # read all connection items for parsing
  readarray -t CONNECTIONS < <(echo "$HOOKS_YAML" | yq -o=j -I=0 '.connections[]' -)
  readarray -t CONNECTION_NAMES < <(echo "$HOOKS_YAML" | yq '.connections | .. | select(has("name")) | .name' -)

  # read all scp items for parsing
  readarray -t SCPS < <(echo "$HOOKS_YAML" | yq -o=j -I=0 '.deploy.scp[]' -)

  # for error handling, count the amount of times a certificate was found or executed
  SCP_EXEC_COUNT=0

  # for each SCP item in .deploy.scp yaml/json
  for SCP in "${SCPS[@]}"; do
    # matching the scp connection variable to a connection

    # error handling for missing or too many connections
    TEST_CONNECTION_NAMES=()
    for CONNECTION in "${CONNECTION_NAMES[@]}"; do
      if [[ "$CONNECTION" == "$(echo "$SCP" | yq '.connection' -)" ]]; then
        TEST_CONNECTION_NAMES+=($CONNECTION)
      fi
    done

    # error messaging and escape to next SCP item - connection settings do not exist
    if [[ ${#TEST_CONNECTION_NAMES[@]} == 0 ]]; then
      echo "error: No connection found for SCP '$(echo "$SCP" | yq '.connection' -)'"
      continue
    elif [[ ${#TEST_CONNECTION_NAMES[@]} > 1 ]]; then
      echo "error: too many connections found for SCP '$(echo "$SCP" | yq '.connection' -)'"
      continue
    fi

    # set variables for SCP connection
    for CONNECTION in "${CONNECTIONS[@]}"; do
      if [[ $(echo "$CONNECTION" | yq '.name' -) == $(echo "$SCP" | yq '.connection' -)  ]]; then
        REMOTE_HOST=$(echo "$CONNECTION" | yq '.host' -)
        REMOTE_USER=$(echo "$CONNECTION" | yq '.remote-user' -)
        SSH_KEYFILE=$(echo "$CONNECTION" | yq '.ssh-keyfile' -)
        break
      fi
    done

    # default variable - if SSH_KEYFILE value does not contain a path, use default location
    if [[ ! "$SSH_KEYFILE" =~ '/' ]]; then
       SSH_KEYFILE=${SSH_KEY_FILE_PATH}/${SSH_KEYFILE}
    fi

    # override default variable - connection timeout
    if [[ $(echo "$CONNECTION" | yq '. | has("timeout")' -) == true ]]; then
      CONNECTION_TIMEOUT=$(echo "$CONNECTION" | yq '.timeout' -)
    else
      CONNECTION_TIMEOUT=${CONNECTION_TIMEOUT_DEFAULT}
    fi

    # all certificates for parsing from the scp item
    readarray -t SCP_CERTS < <(echo "$SCP" | yq '.certificates[]' -)
    for SCP_CERT in "${SCP_CERTS[@]}"; do

      # match SCP certificate to renewal certificate name and set variables for SCP
      if [[ $(echo "$SCP_CERT" | yq '.name' -) == "${CERTBOT_CERT_NAME}" ]]; then
        ((SCP_EXEC_COUNT++))
        REMOTE_PATH=$(echo "$SCP_CERT" | yq '.path' -)

        echo "info: executing SCP transfer of certificate '$CERTBOT_CERT_NAME' to '${REMOTE_PATH}' on '$(echo "$SCP" | yq '.connection' -)' ($REMOTE_HOST)"

        # error messaging and escape to next SCP item - ssh key files does not exist
        if [[ ! -f "${SSH_KEYFILE}" ]]; then
          echo "error: failed transfer: ssh key file '${SSH_KEYFILE}' does not exist"
          continue
        fi

        # set variables for certificate files for SCP and command execution
        readarray -t SCP_CERT_FILES < <(echo "$SCP_CERT" | yq '.files[]' -)
        for SCP_CERT_FILE in  "${SCP_CERT_FILES[@]}"; do
          # scp file transfer execution
          echo "info: transferring file '$SCP_CERT_FILE'"
          scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=${CONNECTION_TIMEOUT} -i ${SSH_KEYFILE} ${RENEWED_LINEAGE}/${SCP_CERT_FILE} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}
          exiterr=$?
          if [ ${exiterr} -eq 0 ]; then
            echo "info: successfully transferred file '$SCP_CERT_FILE'"
          else
            echo "error: failed transfer: exit code ${exiterr}"
          fi
        done
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
  echo "Error: No renewal lineage, if executed outside of certbot renewal-hook, please specify a cert-name using --cert-name 'subdomain.domain-name.tld-0001' or --version"
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
      --version)
        ARG_VERSION="true"
        shift
        ;;
      --cert-name)
        ARG_CERT_NAME="${2}"
        shift
        ;;
    esac
    shift
  done

  # argument: '--version' will only show versioning even if other options are set
  if [[ $ARG_VERSION == true ]]; then
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
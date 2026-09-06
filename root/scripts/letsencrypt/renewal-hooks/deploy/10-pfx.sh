#!/bin/bash

##############################################################################
#                                  10-pfx.sh                                 #
##############################################################################
#
# This script is for certbots renewal-hooks to create pfx certificate files.
#
# The YAML files default location is '/config/certbot-controller.yaml'. The
# PFX filename will be the cert name separated by '_' for example,
# "subdomain_domain_tld.pfx". Default passwords are the filename without the
# extension, for example "subdomain_domain_tld". Passwords can also be defined
# within the yaml.
#
# Example YAML file:
# hooks:
#   deploy:
#     pfx:
#       certificates:
#         - name: subdomain.domain.tld
#           password: super-secret-password #optional default is the domain
#         - name: subdomain2.domain.tld-0001
#
# Script Documentation: https://github.com/soleous/certbot-controller

##############################################################################
#                                 VERSIONING                                 #
##############################################################################
VERSION="1.2"
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

  # read hooks.deploy.pfx block from certbot-controller.yaml
  PFX_YAML=$(yq '.hooks.deploy.pfx' ${SCP_CONFIG_FILE})

  # read all pfx certificate items for parsing
  readarray -t PFX_CERTS < <(echo "$PFX_YAML" | yq -o=j -I=0 '.certificates[]' -)

  # for error handling, count the amount of times a certificate was found or executed
  PFX_EXEC_COUNT=0

  # for each certificate item in .deploy.pfx yaml/json
  for PFX_CERT in "${PFX_CERTS[@]}"; do

    # match PFX certificate to renewal certificate name
    if [[ $(echo "$PFX_CERT" | yq '.name' -) == "${CERTBOT_CERT_NAME}" ]]; then
      ((PFX_EXEC_COUNT++))

      echo "info: creating PFX certificate file for certificate '$CERTBOT_CERT_NAME'"

      # default variables - openssl command
      FILENAME=${CERTBOT_CERT_NAME//\./_}
      OPENSSL_OUT_FILE="${RENEWED_LINEAGE}/${FILENAME}.pfx"
      CERT_PRIVKEY_FILE="${RENEWED_LINEAGE}/privkey.pem"
      CERT_CERT_FILE="${RENEWED_LINEAGE}/cert.pem"
      CERT_CHAIN_FILE="${RENEWED_LINEAGE}/chain.pem"

      # override default variable - pfx password
      if [[ $(echo "$PFX_CERT" | yq '. | has("password")' -) == true ]]; then
        PFX_CERT_PASSWORD=$(echo "$PFX_CERT" | yq '.password' -)
      else
        PFX_CERT_PASSWORD=${FILENAME}
      fi

      openssl pkcs12 \
        -export -out ${OPENSSL_OUT_FILE} \
        -inkey ${CERT_PRIVKEY_FILE} \
        -in ${CERT_CERT_FILE} \
        -certfile ${CERT_CHAIN_FILE} \
        -password pass:$PFX_CERT_PASSWORD
      exiterr=$?
      if [ ${exiterr} -eq 0 ]; then
        echo "info: successfully created file '${OPENSSL_OUT_FILE}'"
      else
        echo "error: failed creation: exit code ${exiterr}"
      fi
      # change file permissions, default 600
      chmod 660 $OPENSSL_OUT_FILE
    fi
  done

# error handling, for cli execution
if [[ "$PFX_EXEC_COUNT" == 0 ]]; then
    if [[ -n "$ARG_CERT_NAME" ]]; then
      echo "info: no PFX configuration for certificate '$CERTBOT_CERT_NAME'. See documentation at 'https://github.com/soleous/certbot-controller'"
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
    2> >(awk -v prefix="DEPLOY-HOOK-PFX:" '{ print prefix, $0 }' >&2) \
    > >(awk -v prefix="DEPLOY-HOOK-PFX:" '{ print prefix, $0 }')
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
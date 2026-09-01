# image defaults arguments
ARG CERTBOT_IMAGE=certbot/certbot
# ARG CERTBOT_IMAGE_TAG=${CERTBOT_VERSION}

ARG CERTBOT_IMAGE_TAG

# base image
FROM ${CERTBOT_IMAGE}:${CERTBOT_IMAGE_TAG:-latest}

# add s6 overlay
# PREVIOUS VERSION: 3.2.1.0
ARG S6_OVERLAY_VERSION=3.2.3.2

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

ENV \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
  S6_VERBOSITY=1

# python pip
ENV PIP_ROOT_USER_ACTION=ignore

# install runtime packages
RUN \
  echo "**** Upgrade and installing runtime packages ****" && \
  apk upgrade --no-cache && \
  apk add --update --no-cache \
    bash \
    shadow \
    cronie \
    busybox-suid \
    openssl \
    openssh-client \
    yq

# create non-root users and groups
ARG \
  PUID=911 \
  PGID=911

ENV \
  NON_ROOT_USER="certbot" \
  CONTAINER_DIR_CONFIG="/config"

RUN \
  echo "**** Create none-root group and user: ${NON_ROOT_USER} ****" && \
  groupadd -r -g "${PGID}" ${NON_ROOT_USER} && \
  useradd -u "${PUID}" -g "${PGID}" -d ${CONTAINER_DIR_CONFIG} -s /bin/false ${NON_ROOT_USER} && \
  mkdir -p ${CONTAINER_DIR_CONFIG} && \
  chown -R ${NON_ROOT_USER}:${NON_ROOT_USER} ${CONTAINER_DIR_CONFIG}

# create directories and set permissions for non-root application use

ENV \
  CERTBOT_DIR_PLUGINS="${CONTAINER_DIR_CONFIG}/plugins" \
  CONTAINER_DIR_SCRIPTS="/scripts" \
  CERTBOT_DIR_CONFIG="/etc/letsencrypt" \
  CERTBOT_DIR_WORK="/var/lib/letsencrypt" \
  CERTBOT_DIR_LOGS="/var/log/letsencrypt"

RUN \
  echo "**** Create directories and set owner for non-root user: ${NON_ROOT_USER} ****" && \
  mkdir -p \
    ${CERTBOT_DIR_PLUGINS} \
    ${CERTBOT_DIR_CONFIG} \
    ${CERTBOT_DIR_WORK} \
    ${CERTBOT_DIR_LOGS} && \
  chown -R ${NON_ROOT_USER}:${NON_ROOT_USER} \
    ${CERTBOT_DIR_CONFIG} \
    ${CERTBOT_DIR_WORK} \
    ${CERTBOT_DIR_LOGS}

# Tidy up
RUN \
  echo "**** Cleanup ****" && \
  rm -rf /tmp/*

# add local files
COPY --chmod=755 root/ /
RUN \
  echo "**** Changing permissions of s6 services ****" && \
  find /etc/s6-overlay/s6-rc.d/ -type f -exec chmod 644 {} + && \
  find /etc/s6-overlay/s6-rc.d/ -type f -name 'run' -exec chmod 755 {} + && \
  find /etc/s6-overlay/s6-rc.d/ -type f -name 'finish' -exec chmod 755 {} + 

# create metadata
ARG \
  CERTBOT_IMAGE \
  CERTBOT_IMAGE_TAG

LABEL certbot_image=${CERTBOT_IMAGE}:${CERTBOT_IMAGE_TAG}
LABEL s6_overlay_version=${S6_OVERLAY_VERSION}

ENTRYPOINT ["/entrypoint.sh"]

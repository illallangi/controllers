FROM ghcr.io/flant/shell-operator:v1.4.5 as shell-operator
RUN \
  mkdir -p \
    /rootfs/frameworks/shell \
    /rootfs/usr/bin \
  && \
  cp \
    /usr/bin/jq \
    /rootfs/usr/bin \
  && \
  cp \
    /shell-operator \
    /shell_lib.sh \
    /rootfs \
  && \ 
  cp \
    /frameworks/shell/context.sh \
    /frameworks/shell/hook.sh \
    /rootfs/frameworks/shell

# Main image
FROM docker.io/library/debian:bookworm-20231218
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
# Install packages
  apt-get update \
  && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates=20230311 \
    curl=7.88.1-10+deb12u5 \
    python3-pip=23.0.1+dfsg-1 \
  && \
  apt-get clean \
  && \
  rm -rf /var/lib/apt/lists/* \
  && \
# Install s6 overlay
  if [ "$(uname -m)" = "x86_64" ]; then \
    curl \
      https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer \
      --location \
      --output /tmp/s6-overlay-installer \
      --silent \
  ; fi \
  && \
  if [ "$(uname -m)" = "aarch64" ]; then \
    curl \
      https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-aarch64-installer \
      --location \
      --output /tmp/s6-overlay-installer \
      --silent \
  ; fi \
  && \
  chmod +x \
    /tmp/s6-overlay-installer \
  && \
  /tmp/s6-overlay-installer / \
  && \
  rm /tmp/s6-overlay-installer \
  && \
# Install kubectl
  if [ "$(uname -m)" = "x86_64" ]; then \
    curl \
      https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl \
      --location \
      --output /usr/bin/kubectl \
      --silent \
  ; fi \
  && \
  if [ "$(uname -m)" = "aarch64" ]; then \
    curl \
      https://dl.k8s.io/release/v1.29.0/bin/linux/arm64/kubectl \
      --location \
      --output /usr/bin/kubectl \
      --silent \
  ; fi \
  && \
  chmod +x \
    /usr/bin/kubectl \
  && \
# Make directories
  mkdir -p /hooks /usr/src/app

# Install shell-operator
COPY --from=shell-operator /rootfs /

# Set environment variables
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# Set command
CMD ["/init"]

# Install Python requirements
COPY rootfs/usr/src/app/requirements.txt /usr/src/app/requirements.txt
RUN python3 -m pip install --no-cache-dir --break-system-packages -r /usr/src/app/requirements.txt

# Copy rootfs
COPY rootfs /

# Install Python package
RUN python3 -m pip install --no-cache-dir --break-system-packages  /usr/src/app

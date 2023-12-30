FROM ghcr.io/flant/shell-operator:v1.4.5 as shell-operator

# kubectl build image
FROM docker.io/library/debian:bookworm-20231218 as kubectl
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install packages
RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
  && \
  apt-get install -y --no-install-recommends \
    ca-certificates=20230311 \
    curl=7.88.1-10+deb12u5 \
  && \
  apt-get clean \
  && \
  rm -rf /var/lib/apt/lists/* \
  && \
  kubectlArch="$(echo "${TARGETPLATFORM:-linux/amd64}" | sed "s/\/v7//")" \
  && \
  kubectlVersion="$(curl https://dl.k8s.io/release/stable.txt --location --silent)" \
  && \
  echo "Download kubectl ${kubectlVersion} for ${kubectlArch}" \
  && \
  curl "https://dl.k8s.io/release/${kubectlVersion}/bin/${kubectlArch}/kubectl" --location --output /usr/bin/kubectl --silent \
  && \
  chmod +x /usr/bin/kubectl

# Main image
FROM docker.io/library/debian:bookworm-20231218
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install packages
RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
  && \
  apt-get install -y --no-install-recommends \
    ca-certificates=20230311 \
    curl=7.88.1-10+deb12u5 \
    python3-pip=23.0.1+dfsg-1 \
  && \
  apt-get clean \
  && \
  rm -rf /var/lib/apt/lists/* \
  && \
  mkdir -p /hooks /usr/src/app

COPY --from=kubectl /bin/kubectl /usr/bin/kubectl

COPY --from=shell-operator /frameworks/shell/context.sh /frameworks/shell
COPY --from=shell-operator /frameworks/shell/hook.sh /frameworks/shell
COPY --from=shell-operator /shell_lib.sh /

COPY --from=shell-operator /usr/bin/jq /usr/bin
COPY --from=shell-operator /shell-operator /

# Install s6 overlay
RUN \
  if [ "$(uname -m)" = "x86_64" ]; then \
    curl https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer --location --output /tmp/s6-overlay-installer \
  ; fi \
  && \
  if [ "$(uname -m)" = "aarch64" ]; then \
    curl https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-aarch64-installer --location --output /tmp/s6-overlay-installer \
  ; fi \
  && \
  chmod +x \
    /tmp/s6-overlay-installer \
  && \
  /tmp/s6-overlay-installer / \
  && \
  rm /tmp/s6-overlay-installer

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# Set command
CMD ["/init"]

# Install Python packages
COPY rootfs/usr/src/app/requirements.txt /usr/src/app/requirements.txt
RUN python3 -m pip install --no-cache-dir --break-system-packages -r /usr/src/app/requirements.txt

# Copy rootfs
COPY rootfs /

RUN python3 -m pip install --no-cache-dir --break-system-packages  /usr/src/app

ENV SHELL_OPERATOR_HOOKS_DIR /hooks
ENV LOG_TYPE json
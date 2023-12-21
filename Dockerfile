FROM ghcr.io/flant/shell-operator:v1.3.1 as shell-operator

FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine:3.18
RUN \
  apk --no-cache add \
    ca-certificates=20230506-r0 \
    bash=5.2.15-r5 \
    sed=4.9-r2 \
    tini=0.19.0-r1 \
    python3=3.11.6-r0 \
    py3-pip=23.1.2-r0 \
  && \
    kubectlArch=$(echo ${TARGETPLATFORM:-linux/amd64} | sed 's/\/v7//') \
  && \
  echo "Download kubectl for ${kubectlArch}" \
  && \
  wget https://storage.googleapis.com/kubernetes-release/release/v1.27.4/bin/${kubectlArch}/kubectl -O /bin/kubectl \
  && \
  chmod +x /bin/kubectl \
  && \
  mkdir -p /hooks /usr/src/app

COPY --from=shell-operator /frameworks/shell/context.sh /frameworks/shell
COPY --from=shell-operator /frameworks/shell/hook.sh /frameworks/shell
COPY --from=shell-operator /shell_lib.sh /

COPY --from=shell-operator /usr/bin/jq /usr/bin
COPY --from=shell-operator /shell-operator /

COPY requirements.txt /usr/src/app

WORKDIR /usr/src/app
RUN python3 -m pip install --no-cache-dir -r requirements.txt

COPY . /usr/src/app
RUN python3 -m pip install --no-cache-dir .


WORKDIR /
ENV SHELL_OPERATOR_HOOKS_DIR /hooks
ENV LOG_TYPE json
ENTRYPOINT ["/sbin/tini", "--", "/shell-operator"]
CMD ["start"]
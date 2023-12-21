FROM ghcr.io/flant/shell-operator:v1.4.4 as shell-operator

FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine:3.18
RUN apk --no-cache add ca-certificates bash sed tini python3 py3-pip && \
    kubectlArch=$(echo ${TARGETPLATFORM:-linux/amd64} | sed 's/\/v7//') && \
    echo "Download kubectl for ${kubectlArch}" && \
    wget https://storage.googleapis.com/kubernetes-release/release/v1.27.4/bin/${kubectlArch}/kubectl -O /bin/kubectl && \
    chmod +x /bin/kubectl && \
    mkdir -p /hooks /usr/src/app

COPY --from=shell-operator /frameworks/shell/context.sh /frameworks/shell
COPY --from=shell-operator /frameworks/shell/hook.sh /frameworks/shell
COPY --from=shell-operator /shell_lib.sh /

COPY --from=shell-operator /usr/bin/jq /usr/bin
COPY --from=shell-operator /shell-operator /

COPY requirements.txt /usr/src/app

WORKDIR /usr/src/app
RUN python3 -m pip install -r requirements.txt

COPY . /usr/src/app
RUN python3 -m pip install --no-cache-dir .


WORKDIR /
ENV SHELL_OPERATOR_HOOKS_DIR /hooks
ENV LOG_TYPE json
ENTRYPOINT ["/sbin/tini", "--", "/shell-operator"]
CMD ["start"]
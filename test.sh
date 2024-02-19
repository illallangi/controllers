#!/bin/bash
set -e

podman build --format docker --build-arg hooks=plexes . -t registry.great-tuna.ts.net/plex-controller:latest
podman push registry.great-tuna.ts.net/plex-controller:latest
kubectl delete deploy -n kube-system plex-controller || true
cat manifests/plex-controller.yaml | sed "s|ghcr.io/illallangi|registry.great-tuna.ts.net|g" | kubectl apply -f -

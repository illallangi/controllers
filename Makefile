.PHONY: help clean-% build-% test-%

# Require the DEV_REGISTRY environment variable to be set
ifndef DEV_REGISTRY
$(error DEV_REGISTRY is not set)
endif

help:
	@echo "make clean-<name>"
	@echo "    Remove the image for the controller named <name> and delete the deployment from the cluster"
	@echo "make build-<name>"
	@echo "    Build the image for the controller named <name>"
	@echo "make test-<name>"
	@echo "    Build the image for the controller named <name> and deploy it to the cluster"

clean-%:
	@podman rmi -f ${DEV_REGISTRY}/$(*)-controller:latest || true
	@kubectl delete -A deploy -l app.kubernetes.io/instance=$(*),app.kubernetes.io/name=controller --ignore-not-found
	@rm -f manifests/$(*)-controller.digest

build-%:
	@podman build -t ${DEV_REGISTRY}/$(*)-controller:latest --format=docker --build-arg hooks=$(*) .
	@podman push ${DEV_REGISTRY}/$(*)-controller:latest --digestfile=manifests/$(*)-controller.digest

test-%: build-%
	@kubectl delete -A deploy -l app.kubernetes.io/instance=$(*),app.kubernetes.io/name=controller --ignore-not-found --wait || true
	@DIGEST=$$(cat manifests/$(*)-controller.digest) && \
	  cat manifests/$(*)-controller.yaml | sed "s|image: .*|image: ${DEV_REGISTRY}/$(*)-controller@$${DIGEST}|" | kubectl apply -f -

log-%:
	@kubectl logs -f -n kube-system -l app.kubernetes.io/instance=$(*),app.kubernetes.io/name=controller | jq -c

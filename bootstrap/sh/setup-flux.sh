# ACS Cell Gateway bootstrap script
# Flux configuration

die () {
  echo "$@" >&2
  exit 1
}

echo Configuring Flux...

[ -n "$CLUSTER_NAME" ] || die "No cluster name provided!"
[ -n "$FLUX_URL" ] || die "No Flux URL provided!"
[ -n "$FLUX_TOKEN" ] || die "No Flux token provided!"

name="cluster-${CLUSTER_NAME}"

flux create secret git temp-token --url="$FLUX_URL" --bearer-token="$FLUX_TOKEN"
flux create source git "$name" --secret-ref=temp-token --url="$FLUX_URL"
flux create kustomization "$name" --source="GitRepository/$name"
flux reconcile source git "$name"
flux reconcile kustomization "$name"
kubectl delete -n flux-system secret/temp-token
flux reconcile source git "$name"

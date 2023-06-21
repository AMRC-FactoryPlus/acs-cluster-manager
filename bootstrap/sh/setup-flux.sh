# ACS Cell Gateway bootstrap script
# Flux configuration

echo Configuring Flux...
flux create secret git temp-token --url="$FLUX_URL" --bearer-token="$FLUX_TOKEN"
flux create source git cluster."$NAME" --secret-ref=temp-token --url="$FLUX_URL"
flux create kustomization cluster."$NAME" --source=GitRepository/cluster."$NAME"
flux reconcile source git cluster."$NAME"
flux reconcile kustomization cluster."$NAME"
kubectl delete -n flux-system secret/temp-token
flux reconcile source git cluster."$NAME"

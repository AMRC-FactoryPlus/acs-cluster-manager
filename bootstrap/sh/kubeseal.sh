# ACS Cell Gateway bootstrap script
# Sealed Secrets setup

echo Configuring Sealed Secrets...
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets
tar -xvzf ./install/kubeseal.tar.gz -C install kubeseal

until [ -s ./install/kubesealCert.pem ]; do
  echo "Waiting for certificate..."
  sleep 2

  ./install/kubeseal --controller-name sealed-secrets \
    --controller-namespace default \
    --fetch-cert >./install/kubesealCert.pem
done

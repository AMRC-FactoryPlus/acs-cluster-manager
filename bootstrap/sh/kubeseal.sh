# ACS Cell Gateway bootstrap script
# Sealed Secrets setup

echo Configuring Sealed Secrets...
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets
tar -xvzf ./install/kubeseal.tar.gz -C install kubeseal

echo "Fetching sealed secrets certificate..."
sleep 3

while true
do
  ./install/kubeseal --controller-name sealed-secrets \
    --controller-namespace default \
    --fetch-cert >./install/kubesealCert.pem \
    || true

  [ -s ./install/kubesealCert.pem ] && break

  echo "Waiting for certificate..."
  sleep 5  
done

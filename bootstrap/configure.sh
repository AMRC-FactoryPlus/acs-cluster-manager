#!/bin/bash

# Todo:
# - Move REST calls to JS for now. One file output jq to extract vars
# - Optional name for testing instead of hostname
# - Optional "which of these is your network north/south" question - skips if args passed
# - This should be served from the central cluster and the args should be added as part of the central Helm chart

set -ex
export DEBIAN_FRONTEND=noninteractive

# Add defaults here if required
#baseURL = ""
#realm = ""

scheme=https

while getopts u:r:S flag; do
  case "${flag}" in
  u) baseURL=${OPTARG} ;;
  r) realm=${OPTARG} ;;
  S) scheme=http ;;
  esac
done

[[ -z "$baseURL" ]] && {
  echo "baseURL not provided (-u)"
  exit 1
}
[[ -z "$realm" ]] && {
  echo "Realm not provided (-r)"
  exit 1
}

read -p "Does the gateway have an I/O box with two network ports on the front? (y/n)" ioBox

if [ "$ioBox" = "n" ]; then
  echo "This script only currently supports Cell Gateways with an I/O box"
  exit 1
fi


echo Downloading installation scripts...
rm -rf install
mkdir -p install
(
    cd install
    fetch="curl -sSL --fail-early"
    $fetch https://apt.kitware.com/keys/kitware-archive-latest.asc >kitware.key
    $fetch https://deb.nodesource.com/setup_20.x >node-apt.sh
    $fetch https://get.k3s.io >k3s.sh
    $fetch https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 >helm.sh
    $fetch https://fluxcd.io/install.sh >flux.sh
)

echo Running necessary steps as root via sudo...
sudo /bin/sh ./sh/as-root.sh

echo "Setting KUBECONFIG for use by k8s tools..."
export KUBECONFIG="$(realpath ./install/k3s.yaml)"
exit 0

echo Configuring Sealed Secrets...
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm --kubeconfig=/etc/rancher/k3s/k3s.yaml install sealed-secrets sealed-secrets/sealed-secrets
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.22.0/kubeseal-0.22.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.22.0-linux-amd64.tar.gz kubeseal

until [ -s kubesealCert.pem ]; do
  echo "Waiting for certificate..."
  sleep 2

  kubeseal --kubeconfig=/etc/rancher/k3s/k3s.yaml --controller-name sealed-secrets --controller-namespace default --fetch-cert >kubesealCert.pem
done

rm kubeseal-0.22.0-linux-amd64.tar.gz
rm ./kubeseal

echo Configuring Kerberos...
printf "[libdefaults]

    default_realm = $realm
    dns_canonicalize_hostname = false
    udp_preference_limit = 1
    spake_preauth_groups = edwards25519

[domain_realm]
    $baseURL = $realm

[realms]

    $realm = {
        kdc = kdc.$baseURL
        admin_server = kadmin.$baseURL
        disable_encrypted_timestamp = true
    }
" >/etc/krb5.conf
export KRB5CCNAME=$(mktemp)
read -p "Please enter the username of a Factory+ administrator user: " KERBUSER
kinit $KERBUSER

echo Registering edge cluster...
EDGE_URL="${scheme}://edge.${baseURL}" npm run start

echo Configuring Flux...

# Next, get a token from the git component
TOKEN=$(curl --negotiate -u : "git.$baseURL/token" | jq -r .token)
NAME=$(hostname)

flux create secret git temp-token --bearer-token=$TOKEN
flux create source git cluster.$NAME --secret-ref=temp-token --url=$FLUX
flux create kustomization cluster.$NAME --source=GitRepository/cluster.$NAME
flux reconcile source git cluster.$NAME
flux reconcile kustomization cluster.$NAME
kubectl delete -n flux-system secret/temp-token
flux reconcile source git cluster.$NAME

#!/bin/bash

# Todo:
# - Move REST calls to JS for now. One file output jq to extract vars
# - Optional name for testing instead of hostname
# - Optional "which of these is your network north/south" question - skips if args passed
# - This should be served from the central cluster and the args should be added as part of the central Helm chart

if [ "$(id -u)" = 0 ]
then
    cat <<MSG
DON'T run this script as root. Run as a normal user with sudo rights, and
you will be prompted for a sudo password when necessary.
MSG
    exit 1
fi

set -ex

. ./sh/getopts.sh

rm -rf install
mkdir -p install

. ./sh/downloads.sh

echo Running necessary steps as root via sudo...
ACS_DOMAIN="$baseURL" REALM="$realm" sudo -E /bin/sh ./sh/as-root.sh

echo "Setting KUBECONFIG for use by k8s tools..."
export KUBECONFIG="$(realpath ./install/k3s.yaml)"

. ./sh/kubeseal.sh

echo Installing Javascript dependencies...
npm install

export KRB5CCNAME=$(mktemp)
read -p "Please enter the username of a Factory+ administrator user: " KERBUSER
kinit $KERBUSER

echo Registering edge cluster...
node src/bootstrap.js "${scheme}://edge.${baseURL}" "$template"

. ./install/cluster-info.sh
. ./sh/setup-flux.sh

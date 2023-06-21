# ACS Cell Gateway bootstrap script
# Download required software

echo Downloading installation scripts...
(
    cd install
    fetch="curl -sSL --fail-early"
    $fetch https://apt.kitware.com/keys/kitware-archive-latest.asc >kitware.key
    $fetch https://deb.nodesource.com/setup_20.x >node-apt.sh
    $fetch https://get.k3s.io >k3s.sh
    $fetch https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 >helm.sh
    $fetch https://fluxcd.io/install.sh >flux.sh
    $fetch https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.22.0/kubeseal-0.22.0-linux-amd64.tar.gz >kubeseal.tar.gz
)


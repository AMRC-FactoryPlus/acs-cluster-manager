# ACS Cell Gateway bootstrap script
# Install K3s
# This must happen after the network has been configured

if [ "$(id -u)" != 0 ]
then
    echo "Installing software must run as root!" >&2
    exit 1
fi

if [ -z "$SUDO_USER" ]
then
    echo "I don't know who you are! (Run this with sudo.)" >&2
    exit 1
fi

echo Installing K3s...
sh ./install/k3s.sh --cluster-init --disable=traefik --node-ip=10.0.0.1

echo "Copying kubeconfig to ./install..."
install -o "$SUDO_USER" -m 400 /etc/rancher/k3s/k3s.yaml ./install

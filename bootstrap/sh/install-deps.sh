# ACS Cell Gateway bootstrap script
# Install dependencies

if [ "$(id -u)" != 0]
then
    echo "Software installation must run as root!" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo Installing Dependencies...
apt-key add ./install/kitware.key
apt-add-repository 'deb https://apt.kitware.com/ubuntu/ jammy main' -y
apt-get update 

apt-get install -y \
    apt-transport-https ca-certificates gnupg software-properties-common wget
bash ./install/node-apt.sh

apt-get install -y \
    wireguard g++ iptables-persistent dnsmasq krb5-user \
    cmake libkrb5-dev nodejs jq

bash ./install/helm.sh
bash ./install/flux.sh

# ACS Cell Gateway bootstrap script
# Install dependencies

if [ "$(id -u)" != 0]
then
    echo "Software installation must run as root!" >&2
    exit 1
fi

echo Installing Dependencies...
# Repos
apt-key add install/kitware.key
apt-add-repository 'deb https://apt.kitware.com/ubuntu/ jammy main' -y
apt-get update 

# Wireguard, iptables, dnsmasq
apt-get install wireguard g++ iptables-persistent dnsmasq krb5-user -y

# Cmake
apt-get install apt-transport-https ca-certificates gnupg software-properties-common wget
apt-get update
apt-get install cmake libkrb5-dev -y

# NodeJS
bash ./install/node-apt.sh
apt-get install -y nodejs

# Helm
bash ./install/helm.sh
# Flux
bash ./install/flux.sh

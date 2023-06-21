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

read -p "Enter user: " user

# Northbound interface
ENN=$(ip -br l | awk '$1 ~ "enp" { print $1}' | sed -n 1p)

# Southbound interface 1
ENS1=$(ip -br l | awk '$1 ~ "enx" { print $1}' | sed -n 1p)

# Southbound interface 2
ENS2=$(ip -br l | awk '$1 ~ "enx" { print $1}' | sed -n 2p)

[[ -z "$ENN" ]] && {
  echo "Northbound interface could not be found"
  exit 1
}
[[ -z "$ENS1" ]] && {
  echo "First southbound interface could not be found"
  exit 1
}
[[ -z "$ENS2" ]] && {
  echo "Second southbound interface could not be found"
  exit 1
}

# Serial number
SERIAL=$(dmidecode -s system-serial-number | tr [:upper:] [:lower:])

echo Installing Dependencies...
# Wireguard, iptables, dnsmasq
apt-get update && apt-get install wireguard g++ iptables-persistent dnsmasq krb5-user -y

# Cmake
apt-get install apt-transport-https ca-certificates gnupg software-properties-common wget
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
apt-add-repository 'deb https://apt.kitware.com/ubuntu/ jammy main' -y
apt-get update
apt-get install cmake libkrb5-dev -y

# NodeJS
curl -fsSL https://deb.nodesource.com/setup_20.x | -E bash - &&
  apt-get install -y nodejs

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# Flux
curl -s https://fluxcd.io/install.sh | bash

echo Downloading the k3s.io script before we change the network...
curl -sfL https://get.k3s.io -o installK3s.sh

echo Setting hostname...
hostnamectl set-hostname fpcgw-${SERIAL}
echo $(hostname)

echo Configuring network...
echo Adapters found:
echo ENN: $ENN
echo ENS1: $ENS1
echo ENS2: $ENS2

echo Setting iptables...
# Allow all incoming connections
iptables -P INPUT ACCEPT
# Allow all outgoing connections
iptables -P OUTPUT ACCEPT
# Block all forwarded connections
iptables -P FORWARD DROP
# Flush existing firewall rules
iptables -F
# Allow established and related inbound connections on all interfaces
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Allow SSH access on all interfaces
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT
# Block all other incoming requests on the northbound interface
iptables -A INPUT -i $ENN -j DROP
# Save and persist
netfilter-persistent save
iptables-legacy-save

echo Configuring dnsmasq on the 10.0.0.1 interface...
echo -e $"interface=$ENS2\nbind-interfaces\nno-hosts\ndhcp-range=10.0.0.2,10.0.0.150,12h" >"/etc/dnsmasq.conf"
systemctl restart dnsmasq

echo Writing netplan config...
rm /etc/netplan/00*
printf "network:
  version: 2
  renderer: networkd
  ethernets:
    $ENN:
      dhcp4: true
      critical: true
    $ENS1:
      optional: true
      addresses:
        - 192.168.1.100/24
    $ENS2:
      ignore-carrier: true
      addresses:
        - 10.0.0.1/24
" >/etc/netplan/99_config.yaml
netplan apply

echo Changing admin password...
#PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
#usermod -p $(openssl passwd -1 $PASSWORD) fplusadmin
#echo "Password set to:$PASSWORD"

echo Having a nap whilst the network comes back up...
sleep 10

echo Installing K3s...
sh ./installK3s.sh --cluster-init --disable=traefik --node-ip=10.0.0.1 2>&1 && rm ./installK3s.sh

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

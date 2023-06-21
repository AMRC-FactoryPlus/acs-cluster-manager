# ACS Cell Gateway bootstrap script
# Networking setup

if [ "$(id -u)" != 0 ]
then
    echo "Networking setup must run as root!" >&2
    exit 1
fi

# Northbound interface
ENN=$(ip -br l | awk '$1 ~ "enp" { print $1}' | sed -n 1p)

# Southbound interface 1
ENS1=$(ip -br l | awk '$1 ~ "enx" { print $1}' | sed -n 1p)

# Southbound interface 2
ENS2=$(ip -br l | awk '$1 ~ "enx" { print $1}' | sed -n 2p)

if [ -z "$ENN" ]
then
  echo "Northbound interface could not be found"
  exit 1
fi
if [ -z "$ENS1" ]
then
  echo "First southbound interface could not be found"
  exit 1
fi
if [ -z "$ENS2" ]
then
  echo "Second southbound interface could not be found"
  exit 1
fi

# Serial number
SERIAL=$(dmidecode -s system-serial-number | tr [:upper:] [:lower:])
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

echo Having a nap whilst the network comes back up...
sleep 10


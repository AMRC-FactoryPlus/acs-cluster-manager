# ACS Cell Gateway bootstrap script
# Set an admin password

read -p "Enter admin user to set password for: " user

echo Changing admin password...
#PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
#usermod -p $(openssl passwd -1 $PASSWORD) "$user"
#echo "Password set to: $PASSWORD"

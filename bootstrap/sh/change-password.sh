# ACS Cell Gateway bootstrap script
# Set an admin password

echo Changing admin password...
(
    PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
    #echo "${SUDO_USER}:${PASSWORD}" | chpasswd
    echo "Password for ${SUDO_USER} set to: $PASSWORD"
    read -p "Press enter WHEN THIS HAS BEEN RECORDED:" dummy
    tput cuu1 cuu1 ed
)

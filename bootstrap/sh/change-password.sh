# ACS Cell Gateway bootstrap script
# Set an admin password

echo Changing admin password...
(
    PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
    cat <<MSG
Pretending to change password for ${SUDO_USER} to ${PASSWORD}
Press enter WHEN THIS HAS BEEN RECORDED.
Press Ctrl-C to cancel.
MSG
    read -p "OK to change password? " dummy
    #echo "${SUDO_USER}:${PASSWORD}" | chpasswd
    tput cuu 4 ed
)

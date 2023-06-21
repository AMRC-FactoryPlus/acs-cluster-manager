# ACS Cell Gateway bootstrap script
# Get options

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

if [ -z "$baseURL" ]
then
  echo "baseURL not provided (-u)"
  exit 1
fi
if [ -z "$realm" ]
then
  realm="$(echo "$baseURL" | tr a-z A-Z)"
  echo "Realm not provided, defaulting to ${realm}"
fi

read -p "Does the gateway have an I/O box with two network ports on the front? (y/n)" ioBox

if [ "$ioBox" = "n" ]; then
  echo "This script only currently supports Cell Gateways with an I/O box"
  exit 1
fi

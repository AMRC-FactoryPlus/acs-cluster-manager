# ACS Cell Gateway bootstrap script
# Set up krb5.conf

die () {
    echo "$@" >&2
    exit 1
}

[ "$(id -u)" = 0 ] || die "Must create krb5.conf as root!" 
[ -n "$REALM" ] || die "REALM must be set"
[ -n "$ACS_DOMAIN" ] || dir "ACS_DOMAIN must be set"

echo Configuring Kerberos...
cat <<KRB5CONF >/etc/krb5.conf
[libdefaults]
    default_realm = $REALM
    dns_canonicalize_hostname = false
    udp_preference_limit = 1
    spake_preauth_groups = edwards25519

[domain_realm]
    $ACS_DOMAIN = $REALM

[realms]
    $REALM = {
        kdc = kdc.$ACS_DOMAIN
        admin_server = kadmin.$ACS_DOMAIN
        disable_encrypted_timestamp = true
    }
KRB5CONF

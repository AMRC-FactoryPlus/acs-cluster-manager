#!/bin/sh

# ACS Cell Gateway bootstap script
# This script is run from configure.sh via sudo, to perform the
# as-root parts of the setup.

. ./sh/install-deps.sh
. ./sh/network.sh
. ./sh/install-k3s.sh
. ./sh/change-password.sh

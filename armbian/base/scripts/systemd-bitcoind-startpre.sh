#!/bin/bash
# shellcheck disable=SC1091
#
# This script is run by systemd using the ExecStartPre option
# before starting bitcoind.service (Bitcoin Core).
#
# Must be run as 'root' with ExecStartPre=+
#
set -eu

# --- generic functions --------------------------------------------------------

# include functions redis_set() and redis_get()
source /opt/shift/scripts/include/redis.sh.inc

# include errorExit() function
source /opt/shift/scripts/include/errorExit.sh.inc

# include errorExit() function
source /opt/shift/scripts/include/errorExit.sh.inc

# ------------------------------------------------------------------------------

# give Redis time to warm up, must be available afterwards
sleep 2
redis_require

# check if rpcauth credentials exist, or create new ones
RPCAUTH="$(redis_get 'bitcoind:rpcauth')"
REFRESH_RPCAUTH="$(redis_get 'bitcoind:refresh-rpcauth')"

if [ ${#RPCAUTH} -lt 90 ] || [ "${REFRESH_RPCAUTH}" -eq 1 ]; then
    echo "INFO: creating new bitcoind rpc credentials"
    echo "INFO: old bitcoind:rpcauth was ${RPCAUTH}"
    echo "INFO: bitcoind:refresh-rpcauth is ${REFRESH_RPCAUTH}"
    /opt/shift/scripts/bbb-cmd.sh bitcoind refresh_rpcauth
else
    echo "INFO: found bitcoind rpc credentials, no action taken"
fi

# check if SSD is already available to avoid failure
BITCOIN_DIR="/mnt/ssd/bitcoin/.bitcoin"
if [ ! -d "${BITCOIN_DIR}" ] || [ ! -x "${BITCOIN_DIR}" ]; then
    echo "ERR: cannot start 'bitcoind', directory ${BITCOIN_DIR} not accessible"
    errorExit BITCOIND_DIRECTORY_NOT_ACCESSIBLE
else
    echo "INFO: starting 'bitcoind', directory ${BITCOIN_DIR} accessible"
fi

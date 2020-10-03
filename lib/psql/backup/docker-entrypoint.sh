#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
    set -- postgres "$@"
fi

if [ "$1" = 'metricstore' ]; then

    export USER_ID=$(id -u)
    export GROUP_ID=$(id -g)
    envsubst < /passwd.template > /tmp/passwd
    export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
    export NSS_WRAPPER_PASSWD=/tmp/passwd
    export NSS_WRAPPER_GROUP=/etc/group

    # whoami
    # id -u
    # id
    # /usr/libexec/init-pgsql
    echo 'starting up..'
    ln -s /tmp/.s.PGSQL.5432 /var/run/postgresql/.s.PGSQL.5432
    echo "PGDATA="${PGDATA}
    /usr/bin/postgres -D ${PGDATA}/userdata -c config_file=${PGDATA}/userdata/postgresql.conf
    # pg_ctl -D "$PGDATA" -w start -o # "-h ''"
    # exec postgres
fi

# exec "$@"

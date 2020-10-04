#!/bin/bash

set -e

# Add elasticsearch as command if needed
if [ "${1:0:1}" = '-' ]; then
    set -- elastic "$@"
fi

update_configs(){
    CONF_FILE=$1
    sed -i "s/#.*network.host:.*/network.host: 0.0.0.0/g" \
    $CONF_FILE
    # sed -i -r 's#elasticsearch\$RANDOM#'$ES_CLUSTER_NAME'#g' /etc/elasticsearch/elasticsearch.yml
    sed -i -r "s/#.*cluster.name:.*/cluster.name: elasticsearch$RANDOM/g" \
    $CONF_FILE
}

if [ "$1" = 'elastic' ]; then

    export USER_ID=$(id -u)
    export GROUP_ID=$(id -g)
    envsubst < /passwd.template > /tmp/passwd
    export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
    export NSS_WRAPPER_PASSWD=/tmp/passwd
    export NSS_WRAPPER_GROUP=/etc/group

    ES_HOME=/usr/share/elasticsearch
    CONF_DIR=/etc/elasticsearch
    CONF_FILE=/etc/elasticsearch/elasticsearch.yml
    DATA_DIR=/var/lib/elasticsearch
    LOG_DIR=/var/log/elasticsearch
    PID_DIR=/var/run/elasticsearch

    update_configs $CONF_FILE

    sed -ri 's/^-Xm(s|x)[0-9]+[a-z]$/-Xm\1'$ES_JVM_HEAP'/' /etc/elasticsearch/jvm.options
    cat << EOF >> /etc/elasticsearch/jvm.options
-Des.pidfile='$PID_DIR'/elasticsearch.pid
-Des.default.path.home='$ES_HOME'
-Des.default.path.logs='$LOG_DIR'
-Des.default.path.data='$DATA_DIR'
-Des.default.config='$CONF_FILE'
-Des.default.path.conf='$CONF_D'
EOF

    set -- /usr/share/elasticsearch/bin/elasticsearch
    # exec su-exec elasticsearch "$BASH_SOURCE" "$@"

fi

# As argument is not related to elasticsearch,
# then assume that user wants to run his own process,
# for example a `bash` shell to explore this image
exec "$@"

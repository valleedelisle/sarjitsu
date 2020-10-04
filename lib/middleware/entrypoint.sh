#!/bin/bash

set -ex
log(){
  echo -e "[$(date +'%D %H:%M:%S %Z')] - $*"
}

update_configs(){
  if [[ ! -z $ES_HOST ]]; then
    sed -i -r 's#^host\s?=.*#host = '$ES_HOST'#g' /opt/api_server/sar-index.cfg
  else
    sed -i -r 's#^host\s?=.*#host = elasticsearch#g' /opt/api_server/sar-index.cfg
  fi

  sed -i -r 's#^port\s?=.*#port = '$ES_PORT'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^protocol\s?=.*#protocol = '$ES_PROTOCOL'#g' /opt/api_server/sar-index.cfg

  sed -i -r 's#^index_prefix\s?=.*#index_prefix = '$INDEX_PREFIX'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^index_version\s?=.*#index_version = '$BULK_ACTION_COUNT'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^bulk_action_count\s?=.*#bulk_action_count = '$INDEX_VERSION'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^number_of_shards\s?=.*#number_of_shards = '$SHARD_COUNT'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^number_of_replicas\s?=.*#number_of_replicas = '$REPLICAS_COUNT'#g' /opt/api_server/sar-index.cfg

  sed -i -r 's#^ds_name\s?=.*#ds_name = '$GRAFANA_DS_NAME'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^pattern\s?=.*#pattern = '$GRAFANA_DS_PATTERN'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^timeField\s?=.*#timeField = '$GRAFANA_TIMEFIELD'#g' /opt/api_server/sar-index.cfg

  if [[ ! -z $DB_HOST ]]; then
    sed -i -r 's#^db_host\s?=.*#db_host = '$DB_HOST'#g' /opt/api_server/sar-index.cfg
  else
    sed -i -r 's#^db_host\s?=.*#db_host = psql#g' /opt/api_server/sar-index.cfg
  fi
  sed -i -r 's#^db_name\s?=.*#db_name = '$DB_NAME'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^db_user\s?=.*#db_user = '$DB_USER'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^db_password\s?=.*#db_password = '$DB_PASSWORD'#g' /opt/api_server/sar-index.cfg
  sed -i -r 's#^db_port\s?=.*#db_port = '$DB_PORT'#g' /opt/api_server/sar-index.cfg

  sed -i -r 's#^api_port\s?=.*#api_port = '$MIDDLEWARE_PORT'#g' /opt/api_server/sar-index.cfg
}

# -a "$(id -u)" = '0'

#export USER_ID=$(id -u)
#export GROUP_ID=$(id -g)
#envsubst < /opt/api_server/passwd.template > /tmp/passwd
#export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
#export NSS_WRAPPER_PASSWD=/tmp/passwd
#export NSS_WRAPPER_GROUP=/etc/group
id
update_configs
/scripts/es-metadata-handler >> /opt/api_server/es-handler.log
cd /opt/api_server
/opt/api_server/run.py >> /opt/api_server/run.log

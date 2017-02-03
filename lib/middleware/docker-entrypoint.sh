#!/bin/bash

set -e


log(){
  echo -e "[$(date +'%D %H:%M:%S %Z')] - $*"
}

# Add as command if needed
if [ "${1:0:1}" = '-' ]; then
	set -- api_engine "$@"
fi

update_configs(){
  if [[ ! -z $ES_HOST ]]; then
    sed -i -r 's#^host\s?=.*#host = '$ES_HOST'#g' /etc/sar-index.cfg
  else
    sed -i -r 's#^host\s?=.*#host = datasource#g' /etc/sar-index.cfg
  fi

  sed -i -r 's#^port\s?=.*#port = '$ES_PORT'#g' /etc/sar-index.cfg
  sed -i -r 's#^protocol\s?=.*#protocol = '$ES_PROTOCOL'#g' /etc/sar-index.cfg

  sed -i -r 's#^index_prefix\s?=.*#index_prefix = '$INDEX_PREFIX'#g' /etc/sar-index.cfg
  sed -i -r 's#^index_version\s?=.*#index_version = '$BULK_ACTION_COUNT'#g' /etc/sar-index.cfg
  sed -i -r 's#^bulk_action_count\s?=.*#bulk_action_count = '$INDEX_VERSION'#g' /etc/sar-index.cfg
  sed -i -r 's#^number_of_shards\s?=.*#number_of_shards = '$SHARD_COUNT'#g' /etc/sar-index.cfg
  sed -i -r 's#^number_of_replicas\s?=.*#number_of_replicas = '$REPLICAS_COUNT'#g' /etc/sar-index.cfg

  sed -i -r 's#^ds_name\s?=.*#ds_name = '$GRAFANA_DS_NAME'#g' /etc/sar-index.cfg
  sed -i -r 's#^pattern\s?=.*#pattern = '$GRAFANA_DS_PATTERN'#g' /etc/sar-index.cfg
  sed -i -r 's#^timeField\s?=.*#timeField = '$GRAFANA_TIMEFIELD'#g' /etc/sar-index.cfg

  if [[ ! -z $DB_HOST ]]; then
    sed -i -r 's#^db_host\s?=.*#db_host = '$DB_HOST'#g' /etc/sar-index.cfg
  else
    sed -i -r 's#^db_host\s?=.*#db_host = metricstore#g' /etc/sar-index.cfg
  fi
  sed -i -r 's#^db_name\s?=.*#db_name = '$DB_NAME'#g' /etc/sar-index.cfg
  sed -i -r 's#^db_user\s?=.*#db_user = '$DB_USER'#g' /etc/sar-index.cfg
  sed -i -r 's#^db_password\s?=.*#db_password = '$DB_PASSWORD'#g' /etc/sar-index.cfg
  sed -i -r 's#^db_port\s?=.*#db_port = '$DB_PORT'#g' /etc/sar-index.cfg

  sed -i -r 's#^api_port\s?=.*#api_port = '$MIDDLEWARE_PORT'#g' /etc/sar-index.cfg
}

if [ "$1" = 'api_engine' -a "$(id -u)" = '0' ]; then
  update_configs
  /scripts/es-metadata-handler
  cd /opt/api_server
  /opt/api_server/run.py
fi

exec "$@"
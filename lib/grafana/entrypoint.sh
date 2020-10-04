#!/bin/bash

set -x

log(){
  echo -e "[$(date +'%D %H:%M:%S %Z')] - $*"
}
if [[ -z $DB_HOST ]]; then
  DB_HOST='metricstore'
  log "DB_HOST set to default - 'metricstore'"
fi
log "Checking http://$DB_HOST:$DB_PORT"
while :; do
  curl -s http://$DB_HOST:$DB_PORT
  if [ $? -eq 52 ]; then
    set -e
    # 52 is empty reply from server, meaning db is up
    # this is to counter "getsockopt: connection refused to postgres"
    # ref: https://github.com/distributed-system-analysis/sarjitsu/issues/34
    log "connection etablished - [postgres]"
    cd $GRAFANA_PATH
    log "Updating grafana config"
    python3 /update_grafana_conf.py
    source ./packaging/rpm/sysconfig/grafana-server
    log "Starting ${GRAFANA_PATH}/bin/grafana-server"
    ${GRAFANA_PATH}/bin/grafana-server \
                -config ${CONF_FILE} \
                -pidfile ${PID_FILE} \
                -homepath $GRAFANA_PATH \
                cfg:default.paths.logs=${LOG_DIR} \
                cfg:default.paths.data=${DATA_DIR} \
                cfg:default.paths.plugins=${PLUGINS_DIR}
    break
  else
      log "unable to contact $DB_HOST; retrying after 1 second."
      sleep 1
  fi
done

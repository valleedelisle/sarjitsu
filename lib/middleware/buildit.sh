#!/bin/bash -xe
root_dir=$(git rev-parse --show-toplevel)
DIR=""
CONTAINER_NAME=""
ctr1=""
mnt=""
FEDORA_RELEASE=25
source ${root_dir}/lib/buildah.sh
setup_buildah $0
clean_and_setup

home_dir=${mnt}/opt/api_server
buildah run $ctr1 -- dnf -y install initscripts python3-pip postgresql-devel gcc redhat-rpm-config python3-devel
buildah run $ctr1 -- dnf clean all
cp -p conf/requirements.txt ${mnt}/root/requirements.txt
buildah run $ctr1 -- pip3 install --no-cache-dir -r /root/requirements.txt
mkdir -p ${mnt}/scripts $home_dir
cp -pr scripts/* ${mnt}/scripts/
cp -pr api_server/* ${home_dir}/
touch ${home_dir}/sarjitsu_middleware.log
cp conf/sar-index.cfg.example ${home_dir}/sar-index.cfg
buildah run $ctr1 -- sh -c "groupadd flask && useradd -d /opt/api_server -m -s /bin/bash -g flask flask"
buildah run $ctr1 -- sh -c "chown -R flask /docker-entrypoint.sh && \
                     chmod -R ug+rwX /scripts /opt/api_server && \
                     chown -R flask:root /scripts /opt/api_server"

buildah unmount $ctr1
buildah config --user flask $ctr1
buildah config \
   --env ES_HOST=${ES_HOST} \
   --env ES_PORT=${ES_PORT} \
   --env ES_PROTOCOL=${ES_PROTOCOL} \
   --env INDEX_PREFIX=${INDEX_PREFIX} \
   --env BULK_ACTION_COUNT=${BULK_ACTION_COUNT} \
   --env INDEX_VERSION=${INDEX_VERSION} \
   --env SHARD_COUNT=${SHARD_COUNT} \
   --env REPLICAS_COUNT=${REPLICAS_COUNT} \
   --env GRAFANA_DS_NAME=${GRAFANA_DS_NAME} \
   --env GRAFANA_DS_PATTERN=${GRAFANA_DS_PATTERN} \
   --env GRAFANA_TIMEFIELD=${GRAFANA_TIMEFIELD} \
   --env DB_HOST=${DB_HOST} \
   --env DB_NAME=${DB_NAME} \
   --env DB_USER=${DB_USER} \
   --env DB_PASSWORD=${DB_PASSWORD} \
   --env DB_PORT=${DB_PORT} \
   --env MIDDLEWARE_PORT=${MIDDLEWARE_PORT} \
   $ctr1

buildah config --label description="Sarjitsu middleware api with nested aggregate support" $ctr1
buildah config --port ${MIDDLEWARE_PORT} $ctr1
buildah commit $ctr1 sarjitsu:${CONTAINER_NAME}

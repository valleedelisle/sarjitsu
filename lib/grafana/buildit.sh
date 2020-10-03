#!/bin/bash -xe
root_dir=$(git rev-parse --show-toplevel)
DIR=""
CONTAINER_NAME=""
ctr1=""
mnt=""
FEDORA_RELEASE=27
source ${root_dir}/lib/buildah.sh
setup_buildah $0
clean_and_setup

REPO=/home/grafana/go/src/github.com/valleedelisle/grafana
buildah run $ctr1 -- dnf install -y golang npm bzip2
buildah run $ctr1 -- dnf groupinstall -y "Development Tools"
buildah run $ctr1 -- dnf clean all
buildah run $ctr1 -- sh -c "groupadd grafana && useradd -ms /bin/bash -g grafana grafana"
mkdir -p ${mnt}$REPO && git clone --branch nested_agg_query_resurrect https://github.com/valleedelisle/grafana.git ${mnt}$REPO 
mkdir ${mnt}/etc/grafana/ ${mnt}/var/log/grafana ${mnt}/var/lib/grafana
cp conf/grafana.ini.example ${mnt}/etc/grafana/grafana.ini
find ${mnt}${REPO}/pkg/ -type f -exec sed -i 's|github.com/grafana/grafana|github.com/valleedelisle/grafana|g' {} \;
buildah run $ctr1 -- chown -R grafana:grafana /home/grafana /etc/grafana/ /var/log/grafana /var/lib/grafana /docker-entrypoint.sh
buildah run --user grafana $ctr1 -- sh -c "cd $REPO && go run build.go setup && go run build.go build"
buildah run $ctr1 -- npm install -g yarn
buildah run --user grafana $ctr1 -- sh -c "cd $REPO && yarn install --pure-lockfile && npm run build"
buildah unmount $ctr1
buildah config --env GRAFANA_PATH=$REPO \
               --env DB_PORT=$DB_PORT \
               --env GRAFANA_PORT=$GRAFANA_PORT \
               --env GRAFANA_DB_TYPE=$GRAFANA_DB_TYPE \
               --env GRAFANA_TIMEFIELD=$GRAFANA_TIMEFIELD \
               --env GRAFANA_DS_NAME=$GRAFANA_DS_NAME \
               --env GRAFANA_DS_PATTERN=$GRAFANA_DS_PATTERN \
               $ctr1
buildah config --label description="Grafana with nested aggregation support" $ctr1
buildah config --port ${GRAFANA_PORT} $ctr1
buildah commit $ctr1 sarjitsu:${CONTAINER_NAME}

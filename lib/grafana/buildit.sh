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
buildah run $ctr1 -- sh -c "groupadd grafana && useradd -ms /bin/bash -g grafana grafana"
mkdir -p ${mnt}$REPO && git clone --branch nested_agg_query_resurrect https://github.com/valleedelisle/grafana.git ${mnt}$REPO 
mkdir ${mnt}/etc/grafana/ ${mnt}/var/log/grafana ${mnt}/var/lib/grafana
cp conf/grafana.ini.example ${mnt}/etc/grafana/grafana.ini
cp update_grafana_conf.py ${mnt}/
find ${mnt}${REPO}/pkg/ -type f -exec sed -i 's|github.com/grafana/grafana|github.com/valleedelisle/grafana|g' {} \;
buildah run $ctr1 -- chown -R grafana:grafana /update_grafana_conf.py /home/grafana /etc/grafana/ /var/log/grafana /var/lib/grafana /entrypoint.sh
buildah run $ctr1 -- pip3 install requests
buildah run --user grafana $ctr1 -- sh -c "cd $REPO && go run build.go setup && go run build.go build && go clean -r"
buildah run $ctr1 -- npm install -g yarn
buildah run --user grafana $ctr1 -- sh -c "cd $REPO && yarn install --pure-lockfile && npm run build"
cp -p ${mnt}${REPO}/packaging/rpm/sysconfig/grafana-server ${mnt}/home/grafana/sysconfig-grafana-server
cp -p ${mnt}${REPO}/bin/grafana* ${mnt}/home/grafana/
cp -pr ${mnt}${REPO}/public/ ${mnt}/home/grafana/public/
cp -pr ${mnt}${REPO}/conf/ ${mnt}/home/grafana/conf/
rm -rf ${mnt}/home/grafana/{.cache,go}/

buildah run $ctr1 -- dnf remove -y golang npm bzip2
buildah run $ctr1 -- dnf groupremove -y "Development Tools"
buildah config --env GRAFANA_PATH=/home/grafana \
               --env DB_PORT=$DB_PORT \
               --env GRAFANA_PORT=$GRAFANA_PORT \
               --env GRAFANA_DB_TYPE=$GRAFANA_DB_TYPE \
               --env GRAFANA_TIMEFIELD=$GRAFANA_TIMEFIELD \
               --env GRAFANA_DS_NAME=$GRAFANA_DS_NAME \
               --env GRAFANA_DS_PATTERN=$GRAFANA_DS_PATTERN \
               $ctr1
buildah config --label description="Grafana with nested aggregation support" $ctr1
buildah config --port ${GRAFANA_PORT} $ctr1

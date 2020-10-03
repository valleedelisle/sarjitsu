#!/bin/bash -xe
DIR="${0%/*}"
cd $DIR
source $(git rev-parse --show-toplevel)/.env
podman rmi localhost/sarjitsu/backend| cat
buildah rm backend-build | cat
ctr1=$(buildah from --name backend-build fedora:25)
mnt=$(buildah mount $ctr1)
buildah run $ctr1 -- sh -c 'echo -e "fastestmirror=1\ndeltarpm=1\n" | tee -a /etc/dnf/dnf.conf'
buildah run $ctr1 -- dnf update -y
buildah run $ctr1 -- dnf install -y vim bind-utils bash-completion iproute procps iputils
buildah run $ctr1 -- dnf -y install net-tools procps git tar bzip2 redis python3-devel gcc nss_wrapper gettext
buildah run $ctr1 -- dnf clean all
buildah run $ctr1 -- sh -c 'useradd -ms /bin/bash flask && mkdir -p /opt/sarjitsu/conf '
cp conf/passwd.template docker-entrypoint.sh ${mnt}/
cp conf/sarjitsu.ini.example ${mnt}/opt/sarjitsu/conf/sarjitsu.ini
cp conf/sar-index.cfg.example ${mnt}/opt/sarjitsu/conf/sar-index.cfg
cp src/requirements.txt ${mnt}/opt/sarjitsu/
cp conf/passwd.template ${mnt}/passwd.template
buildah run $ctr1 -- sh -c 'cd /opt/sarjitsu/ && pip3 install -r requirements.txt'
cp -pr src/ ${mnt}/opt/sarjitsu/src
buildah run $ctr1 -- sh -c 'chgrp -R 0 /opt/sarjitsu/ \
  && chown -R flask:root /opt/sarjitsu/ \
  && chmod -R a+rwX /opt/sarjitsu/'

rm -f ${mnt}/opt/sarjitsu/src/config_local.py
# VOLUME /var/lib/postgresql/data

buildah unmount $ctr1
buildah config --workingdir /opt/sarjitsu/src $ctr1
buildah config --user flask $ctr1
buildah config \
   --env VOS_CONFIG_PATH=/opt/sarjitsu/conf/sar-index.cfg \
   --env ES_HOST=${ES_HOST} \
   --env ES_PORT=${ES_PORT} \
   --env INDEX_PREFIX=${INDEX_PREFIX} \
   --env INDEX_VERSION=${INDEX_VERSION} \
   --env BULK_ACTION_COUNT=${BULK_ACTION_COUNT} \
   --env SHARD_COUNT=${SHARD_COUNT} \
   --env REPLICAS_COUNT=${REPLICAS_COUNT} \
   --env GRAFANA_HOST=${GRAFANA_HOST} \
   --env GRAFANA_PORT=${GRAFANA_PORT} \
   --env MIDDLEWARE_HOST=${MIDDLEWARE_HOST} \
   --env MIDDLEWARE_PORT=${MIDDLEWARE_PORT} \
   --env MIDDLEWARE_ENDPOINT=${MIDDLEWARE_ENDPOINT} \
   --env BACKEND_SERVER_PORT=${BACKEND_SERVER_PORT} \
   $ctr1

buildah config --author='Archit Sharma' $ctr1
buildah config --label maintainer="David Vallee Delisle <dvd@redhat.com>" $ctr1
buildah config --label build_date="$(date +%F)" $ctr1
buildah config --label name="sarjitsu-backend" $ctr1
buildah config --label description="Sarjitsu backend SAR parser" $ctr1
buildah config --label vendor="DVD.DEV" $ctr1
buildah config --port ${BACKEND_SERVER_PORT} $ctr1
buildah config --entrypoint "/docker-entrypoint.sh" $ctr1
buildah commit $ctr1 sarjitsu/backend

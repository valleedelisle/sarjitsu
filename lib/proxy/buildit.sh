#!/bin/bash -xe
DIR="${0%/*}"
cd $DIR
source $(git rev-parse --show-toplevel)/.env
podman rmi localhost/sarjitsu/nginx | cat
buildah rm nginx-build | cat
ctr1=$(buildah from --name nginx-build fedora:25)
mnt=$(buildah mount $ctr1)
buildah run $ctr1 -- sh -c 'echo -e "fastestmirror=1\ndeltarpm=1\n" | tee -a /etc/dnf/dnf.conf'
buildah run $ctr1 -- dnf update -y
buildah run $ctr1 -- dnf install -y vim bind-utils bash-completion iproute procps iputils
buildah run $ctr1 -- dnf -y install net-tools procps nss_wrapper gettext nginx findutils iproute
buildah run $ctr1 -- dnf clean all
cp conf/sarjitsu_nginx.conf.example ${mnt}/etc/nginx/conf.d/sarjitsu_nginx.conf
cp conf/nginx.conf.example ${mnt}/etc/nginx/nginx.conf
cp conf/passwd.template docker-entrypoint.sh ${mnt}/
mkdir -p ${mnt}/var/cache/nginx
buildah run $ctr1 -- sh -c 'chgrp -R 0 /var/cache/nginx /etc/nginx /var/log/nginx/ /var/lib/nginx/ \
                            && chmod -R g+rwX /var/cache/nginx /etc/nginx /var/log/nginx/ /var/lib/nginx/ \
                            && chown -R nginx:root /var/cache/nginx /etc/nginx/ /var/log/nginx/ /var/lib/nginx/'

buildah unmount $ctr1
buildah config --user nginx $ctr1
buildah config \
   --env BACKEND_HOST=${BACKEND_HOST} \
   --env BACKEND_SERVER_PORT=${BACKEND_SERVER_PORT} \
   --env PROXY_PORT=${PROXY_PORT} \
   $ctr1

buildah config --volume='/var/cache/nginx' $ctr1
buildah config --author='David Vallee Delisle' $ctr1
buildah config --label maintainer="David Vallee Delisle <dvd@redhat.com>" $ctr1
buildah config --label build_date="$(date +%F)" $ctr1
buildah config --label name="sarjitsu-proxy-nginx" $ctr1
buildah config --label description="Sarjitsu nginx proxy" $ctr1
buildah config --label vendor="DVD.DEV" $ctr1
buildah config --port ${PROXY_PORT} $ctr1
buildah config --entrypoint "/docker-entrypoint.sh" $ctr1
buildah commit $ctr1 sarjitsu/nginx

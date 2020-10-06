#!/bin/bash -xe
source ${root_dir}/.env
function setup_buildah() {
  # $1 buildit script path
  DIR="${1%/*}"
  cd $DIR
  CONTAINER_NAME=$(echo $DIR | awk -F "/" '{ print $NF; }')
}
function clean_and_setup() {
  podman rmi ${IMAGE_SOURCE}:$CONTAINER_NAME | cat
  buildah rm ${CONTAINER_NAME}-build | cat
  ctr1=$(buildah from --name ${CONTAINER_NAME}-build fedora:$FEDORA_RELEASE)
  mnt=$(buildah mount $ctr1)
  buildah run $ctr1 -- sh -c 'echo -e "fastestmirror=1\ndeltarpm=1\n" | tee -a /etc/dnf/dnf.conf'
  buildah run $ctr1 -- dnf update -y
  buildah run $ctr1 -- dnf install -y procps iputils net-tools nss_wrapper gettext
  cp conf/passwd.template entrypoint.sh ${mnt}/
  buildah config --author='David Vallee Delisle' $ctr1
  buildah config --label maintainer="David Vallee Delisle <dvd@redhat.com>" $ctr1
  buildah config --label original_author="Archit Sharma <archit.py@gmail.com>" $ctr1
  buildah config --label build_date="$(date +%F)" $ctr1
  buildah config --label name="sarjitsu-${CONTAINER_NAME}" $ctr1
  buildah config --label vendor="DVD.DEV" $ctr1
  buildah config --label vcs-url="https://github.com/valleedelisle/sarjitsu/" $ctr1
  buildah config --entrypoint "/entrypoint.sh" $ctr1
}
function commit_and_push() {
  buildah run $ctr1 -- dnf clean all
  buildah unmount $ctr1
  buildah commit $ctr1 ${IMAGE_SOURCE}:${CONTAINER_NAME}
  podman push ${IMAGE_SOURCE}:${CONTAINER_NAME}
}
trap commit_and_push EXIT

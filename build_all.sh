#!/bin/bash -ex
for f in lib/*/buildit.sh; do
  echo $f;
  buildah unshare bash -xe $f
done

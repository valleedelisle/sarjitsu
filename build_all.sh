#!/bin/bash -ex
for f in lib/*/buildit.sh; do
  echo $f;
  bash -xe $f
done

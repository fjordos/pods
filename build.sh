#!/bin/bash

REPOURL="ghcr.io/fjordos/simple"

if [[ -f podman-login.inc ]] || podman login --get-login $REPOURL ; then
  podman login $(cat podman-login.inc) $REPOURL
else
  echo "When you want to login automatically to $REPOURL, you have to create a podman-login.inc in this directory."
  echo "The content will be injected in thius command: podman login <HERE> \$REPOURL"
  echo "As alternavtive, you can login manually before run the build.sh"
fi
podman login --get-login $REPOURL || exit 1

for COMPONENT in $(find . -mindepth 1 -maxdepth 1 -type d | sed 's#./##') ; do
  if [[ ! -f /$COMPONENT/dont-build ]] ; then
    podman build ./$COMPONENT | tee $COMPONENT.log
    IMG=$(tail -n 1 $COMPONENT.log)
    VERS=$(podman run -ti $IMG rpm -q $COMPONENT | sed "s#$COMPONENT-##" | tr -d "\r")
    for TAG in "$REPOURL/$COMPONENT:latest" "$REPOURL/$COMPONENT:$VERS" "$REPOURL/$COMPONENT:$VERS-$(date +%Y-%m-%d)" ; do
      echo podman tag $IMG $TAG
      podman tag $IMG $TAG
      echo podman push $TAG
      podman push $TAG
    done
  fi
done

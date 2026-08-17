#!/bin/bash

REPOURL="ghcr.io/fjordos/simple"
FVERLATEST=44

if [[ -f podman-login.inc ]] || podman login --get-login $REPOURL ; then
  podman login $(cat podman-login.inc) $REPOURL
else
  echo "When you want to login automatically to $REPOURL, you have to create a podman-login.inc in this directory."
  echo "The content will be injected in thius command: podman login <HERE> \$REPOURL"
  echo "As alternavtive, you can login manually before run the build.sh"
fi
podman login --get-login $REPOURL || exit 1

if false ; then
  DLFSITE="https://dl.fedoraproject.org"
  FARCH="x86_64"
  for FVER in 44 ; do
    podman pull quay.io/fedora/fedora-minimal:${FVER}-${FARCH}
            podman image import --change "LABEL org.opencontainers.image.authors=Gergely\ Lonyai" \
                    --change "LABEL org.opencontainers.image.source=https://github.com/fjordos/pods" \
                    --change "LABEL org.opencontainers.image.description=Base\ FjordOS\ image" \
        --change "LABEL org.opencontainers.image.licenses=GPL-3.0-or-later" \
        --arch ${FARCH} - image-imported
      if [[ "${FVER}" == "${FVERLATEST}" ]] ; then
        podman image tag image-imported "$REPOURL/fjordos-base-minimal:${FVER}-${FTAG}" "$REPOURL/fjordos-base-minimal:${FVER}-latest" "$REPOURL/fjordos-base-minimal:latest"
      else
        podman image tag image-imported "$REPOURL/fjordos-base-minimal:${FVER}-${FTAG}" "$REPOURL/fjordos-base<-minimal:${FVER}-latest"
      fi
  done
fi

#exit 0
for COMPONENT in fjordos-base-minimal $(find . -mindepth 1 -maxdepth 1 -type d -not -name ".*" -not -name "fjordos-*" | sed 's#./##') ; do
  if [[ ! -f ./$COMPONENT/dont-build ]] ; then
    [[ -e ./$COMPONENT/Dockerfile ]] || ln -s Containerfile ./$COMPONENT/Dockerfile
    podman build ./$COMPONENT | tee $COMPONENT.log
    IMG=$(tail -n 1 $COMPONENT.log)
    if [[ "$COMPONENT" == fjordos-* ]] ; then
      case "$COMPONENT" in
      "fjordos-base-minimal")
        VERS="${FVER} ${FVER}-${FARCH}"
        ;;
      "*")
        VERS="invalid"
      esac
    elif [[ "$COMPONENT" == "go" ]] ; then
      VERS=$()
    else
      VERS=$(podman run --rm -ti $IMG rpm -q $COMPONENT | sed "s#$COMPONENT-##" | tr -d "\r")
    fi
    if [[ ${VERS} != "invalid" ]] ; then
        TAGS="$REPOURL/$COMPONENT:latest"
        for TAG in $VERS ; do
          TAGS="$TAGS $REPOURL/$COMPONENT:$TAG $REPOURL/$COMPONENT:$TAG-$(date +%Y-%m-%d)"
        done
      for TAG in $TAGS ; do
        echo podman tag $IMG $TAG
        podman tag $IMG $TAG
        echo podman push $TAG
        podman push $TAG
      done
    fi
  fi
done

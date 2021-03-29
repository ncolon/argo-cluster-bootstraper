#!/bin/bash

function usage() {
  echo "usage: "
  echo "  $0 -c api.clustermanager.example.com -u username [-p password] [-n sealedcontrollernamespace] [-s sealedcontrolledname]"
  exit 1
}

CLUSTER=""
USERNAME=""
PASSWORD=""
CONTROLLERNAMESPACE=""
CONTROLLERNAME=""
APIPORT=""
while getopts "c:u:p:n:s:" opt; do
  case ${opt} in
    c) CLUSTER=${OPTARG} ;;
    u) USERNAME=${OPTARG} ;;
    p) PASSWORD=${OPTARG} ;;
    a) APIPORT=${OPTARG} ;;
    n) CONTROLLERNAMESPACE=${OPTARG} ;;
    s) CONTROLLERNAME=${OPTARG} ;;
  esac
done

CONTROLLERNAMESPACE=${ARGONAMESPACE:-sealed-secrets}
CONTROLLERNAME=${CONTROLLERNAME:-sealed-secrets-controller}
USERNAME=${USERNAME:-kubeadmin}
APIPORT=${APIPORT:-6443}

if [[ "${PASSWORD}" == "" ]]; then
  echo -n "$USERNAME password:"
  read -s PASSWORD
  echo
fi

which oc > /dev/null || exit "install oc in your path"
which kubeseal > /dev/null || exit "install kubeseal in your path"

oc login ${CLUSTER}:${APIPORT} -u ${USERNAME} -p ${PASSWORD} || usage
for file in secret_*.yaml;do
  echo "cat $file | kubeseal --controller-namespace ${CONTROLLERNAMESPACE} --controller-name ${CONTROLLERNAME} --format yaml > bootstrap/sealed$file"
  cat $file | kubeseal --controller-namespace ${CONTROLLERNAMESPACE} --controller-name ${CONTROLLERNAME} --format yaml > bootstrap/sealed$file
  rm $file
done

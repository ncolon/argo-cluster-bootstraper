#!/bin/bash

function usage() {
  echo "usage: "
  echo "  $0 -c api.cluster.example.com -u username [-p password] [-n argonamespace]"
  exit 1
}

CLUSTER=""
USERNAME=""
PASSWORD=""
ARGONAMESPACE=""
APIPORT=""
while getopts "c:u:p:n:" opt; do
  case ${opt} in
    c) CLUSTER=${OPTARG} ;;
    u) USERNAME=${OPTARG} ;;
    p) PASSWORD=${OPTARG} ;;
    n) ARGONAMESPACE=${OPTARG} ;;
    a) APIPORT=${OPTARG}
  esac
done

ARGONAMESPACE=${ARGONAMESPACE:-tools}
USERNAME=${USERNAME:-kubeadmin}
APIPORT=${APIPORT:-6443}

if [[ "${PASSWORD}" == "" ]]; then
  echo -n "$USERNAME password:"
  read -s PASSWORD
  echo
fi

which oc > /dev/null || exit "install oc in your path"


oc login ${CLUSTER}:${APIPORT} -u ${USERNAME} -p ${PASSWORD} || usage
oc create sa argocd-manager -n kube-system

cat << EOF | oc create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
EOF

cat << EOF | oc create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-manager-role
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: kube-system
EOF

ARGO_SA_SECRET=$(oc get sa argocd-manager -o yaml -n kube-system|grep argocd-manager-token|awk '{print $3}')
ARGO_SA_TOKEN=$(oc extract secret/${ARGO_SA_SECRET} -n kube-system --keys=token --to=- 2>&1| grep -v token)
ARGO_SA_CACERT=$(oc extract secret/${ARGO_SA_SECRET} -n kube-system --keys=ca.crt --to=- 2>&1| grep -v ca.crt | base64)


# cat << EOF | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml > ${CLUSTER}_sealedsecret.yaml
cat << EOF  > secret_${CLUSTER}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER}
  namespace: ${ARGONAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: cluster
  annotations:
    argocd.argoproj.io/sync-wave: "1"
type: Opaque
stringData:
  name: ${CLUSTER}
  server: https://${CLUSTER}:6443
  config: |
    {
      "bearerToken": "${ARGO_SA_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${ARGO_SA_CACERT}"
      }
    }
EOF

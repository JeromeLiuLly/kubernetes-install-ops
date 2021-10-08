#!/bin/sh
set -e
##集群搭建--为集群的节点打上角色的标签##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh


###1.移除所有角色的标签，然后重新打上
function init(){
source $K8S_BIN_DIR/environment.sh

# 移除
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    kubectl label node ${node_ip} node-role.kubernetes.io/controlplane-
    kubectl label node ${node_ip} node-role.kubernetes.io/etcd-
    kubectl label node ${node_ip} node-role.kubernetes.io/worker-
  done

for node_ip in ${ETCD_CLUSTER_IPS[@]}
  do
    echo ">>> ${node_ip}"

    kubectl label node ${node_ip} node-role.kubernetes.io/controlplane-
    kubectl label node ${node_ip} node-role.kubernetes.io/etcd-
    kubectl label node ${node_ip} node-role.kubernetes.io/worker-
  done

for node_ip in ${WOKER_IPS[@]}
  do
    echo ">>> ${node_ip}"

    kubectl label node ${node_ip} node-role.kubernetes.io/controlplane-
    kubectl label node ${node_ip} node-role.kubernetes.io/etcd-
    kubectl label node ${node_ip} node-role.kubernetes.io/worker-
  done

# 重新打上标签
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    kubectl label node ${node_ip} node-role.kubernetes.io/controlplane=true --overwrite
    kubectl label node ${node_ip} node-role.kubernetes.io/etcd=false --overwrite
    kubectl label node ${node_ip} node-role.kubernetes.io/worker=false --overwrite
  done

for node_ip in ${ETCD_CLUSTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    kubectl label node ${node_ip} node-role.kubernetes.io/etcd=true --overwrite
  done

for node_ip in ${WOKER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    kubectl label node ${node_ip} node-role.kubernetes.io/worker=true --overwrite
  done
}

function main(){
	init
	echo "=====success====="
}
main "$@"

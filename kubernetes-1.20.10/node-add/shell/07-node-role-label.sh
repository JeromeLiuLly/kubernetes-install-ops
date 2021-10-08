#!/bin/sh
set -e
##集群搭建--为集群的节点打上角色的标签##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh


###1.移除所有角色的标签，然后重新打上
function init(){


for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    kubectl label node ${node_ip} node-role.kubernetes.io/worker-
  done

# 重新打上标签
for node_ip in ${NODE_IPS[@]}
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

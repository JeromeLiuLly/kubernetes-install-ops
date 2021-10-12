#!/bin/sh
set -e
##集群搭建--初始化worker 节点##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh


###1.安装相关组件
function init(){
source $K8S_BIN_DIR/environment.sh
for node_ip in ${WOKER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp -P $SSH_PORT $K8S_WORK_DIR/kubernetes/server/bin/{kube-proxy,kubelet} root@${node_ip}:$K8S_BIN_DIR/
    ssh -p $SSH_PORT root@${node_ip} "chmod +x $K8S_BIN_DIR/*"
  done
}

function main(){
	init
	echo "=====success====="
}
main "$@" 
  
  
  
  
  
  
  
  
  
  
  
  

#!/bin/sh
##集群搭建--复制配置文件到bin目录下做备份##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

###1.复制配置文件到bin目录下做备份
function copy_environment(){

  for node_ip in ${NODE_IPS[@]}
  do
     (
      (
        echo ">>> ${node_ip}"
        ssh -p $SSH_PORT root@${node_ip} "mkdir -p $K8S_BIN_DIR"
        ssh -p $SSH_PORT root@${node_ip} "mkdir -p $K8S_WORK_DIR"
        scp -P $SSH_PORT $DIRNAME/00-environment.sh root@$node_ip:$K8S_BIN_DIR/environment.sh
        scp -P $SSH_PORT $DIRNAME/00-environment.sh root@$node_ip:$K8S_WORK_DIR/00-environment.sh
        scp -P $SSH_PORT $DIRNAME/system-init.sh root@$node_ip:$K8S_WORK_DIR/system-init.sh
        scp -P $SSH_PORT $DIRNAME/kernel-lt-devel-5.4.104-1.el7.elrepo.x86_64.rpm root@$node_ip:$K8S_WORK_DIR/kernel-lt-devel-5.4.104-1.el7.elrepo.x86_64.rpm
        scp -P $SSH_PORT $DIRNAME/kernel-lt-5.4.104-1.el7.elrepo.x86_64.rpm root@$node_ip:$K8S_WORK_DIR/kernel-lt-5.4.104-1.el7.elrepo.x86_64.rpm
        scp -P $SSH_PORT $DIRNAME/passwd-dev_dc.sh root@$node_ip:$K8S_WORK_DIR/passwd-dev_dc.sh
        ssh -p $SSH_PORT root@${node_ip} "chmod +x $K8S_WORK_DIR/*.sh"

		    ssh -p $SSH_PORT root@${node_ip} "sh $K8S_WORK_DIR/system-init.sh"
      )  || echo -e "\033[31m分发文件出现错误\033[0m"
    )  | sed "s/^/[${node_ip}] /g" &
  done

  wait
}


function main(){
copy_environment
echo "====success===="
}

main "$@"

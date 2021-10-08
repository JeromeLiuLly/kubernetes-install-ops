#!/bin/bash
#在路径 ~ 下执行


#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh
cd /root
ssh-keygen -t rsa
for node_ip in ${NODE_IPS[@]}
	do
	  echo ">>> ${node_ip}"
	  ssh-copy-id -o StrictHostKeyChecking=no -p $SSH_PORT root@${node_ip}
	done
#!/bin/sh

set -e
DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

####为node节点安装docker####

###===在master节点上执行===###

###1.分发master节点的docker相关文件
function issue_docker(){
	scp -P $SSH_PORT $K8S_WORK_DIR/docker/* root@$NODE_IP:$K8S_BIN_DIR/
	scp -P $SSH_PORT /etc/systemd/system/docker.service root@$NODE_IP:/etc/systemd/system/
	ssh -p $SSH_PORT root@$NODE_IP "mkdir -p  /etc/docker/ $DOCKER_DIR/{data,exec}"
	scp -P $SSH_PORT /etc/docker/daemon.json root@$NODE_IP:/etc/docker/daemon.json
}
###2.启动 docker 服务
function start_docker(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
}
###3.检查服务运行状态
function check_docker(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl status docker"
	ssh -p $SSH_PORT root@$NODE_IP "docker info"
}
function main(){
	issue_docker
	start_docker
	check_docker
	echo "=====success====="
}

main "$@"
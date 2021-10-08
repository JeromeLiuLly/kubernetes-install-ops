#!/bin/sh

set -e
DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

####为node节点安装kube-apiserver-nginx高可用####

###===在master节点上执行===###
###清理旧的kube-nginx：
function clear_nginx(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl disable kube-nginx || echo 去除kube-nginx开机自启失败 "
	ssh -p $SSH_PORT root@$NODE_IP "systemctl stop kube-nginx || echo 停止旧的kube-nginx失败 "
	ssh -p $SSH_PORT root@$NODE_IP "rm -rf $KUBE_NGINX_DIR"
}

###1.拷贝二进制程序：
function issue_binary(){
	ssh -p $SSH_PORT root@$NODE_IP "mkdir -p $KUBE_NGINX_DIR/{conf,logs,sbin}"
	scp -P $SSH_PORT $K8S_WORK_DIR/nginx-1.15.3/nginx-prefix/sbin/nginx  root@$NODE_IP:$KUBE_NGINX_DIR/sbin/kube-nginx
	ssh -p $SSH_PORT root@$NODE_IP "chmod a+x $KUBE_NGINX_DIR/sbin/*"
}
###2.拷贝 nginx配置文件：
function issue_nginx(){
	scp -P $SSH_PORT $KUBE_NGINX_DIR/conf/kube-nginx.conf root@$NODE_IP:$KUBE_NGINX_DIR/conf/kube-nginx.conf
}
###3.拷贝nginx systemd unit 文件
function issue_nginx_service(){
	scp -P $SSH_PORT /etc/systemd/system/kube-nginx.service root@$NODE_IP:/etc/systemd/system/
}
###4.启动 kube-nginx 服务：
function start_nginx(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl daemon-reload && systemctl enable kube-nginx && systemctl start kube-nginx"
}
###5.检查 kube-nginx 服务运行状态
function check_nginx_service(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl status kube-nginx"

}
function main(){
  clear_nginx
	issue_binary
	issue_nginx
	issue_nginx_service
	start_nginx
	check_nginx_service
	echo "=====success====="
}

main "$@"
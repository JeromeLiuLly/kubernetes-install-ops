#!/bin/sh

set -e
DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

####node节点部署 kube-proxy 组件####
###===在master节点上执行===###

###1.分发 kubeconfig 文件
function issue_kubeconfig(){
	scp -P $SSH_PORT $K8S_CERT_PARENT_DIR/kube-proxy.kubeconfig root@$NODE_IP:$K8S_CERT_PARENT_DIR/
}
###2.创建和分发 kube-proxy 配置文件：
function issue_kube_proxy(){
	cp $K8S_CERT_PARENT_DIR/kube-proxy-config.yaml $K8S_WORK_DIR/kube-proxy-config-$NODE_IP.yaml.template
	sed -i 's/\(bindAddress: \)[^*]*/\1'"${IPADDR}"'/' $K8S_WORK_DIR/kube-proxy-config-$NODE_IP.yaml.template
	sed -i 's/\(healthzBindAddress: \)[^*]*/\1'"${IPADDR}"':10256/' $K8S_WORK_DIR/kube-proxy-config-$NODE_IP.yaml.template
	sed -i 's/\(metricsBindAddress: \)[^*]*/\1'"${IPADDR}"':10249/' $K8S_WORK_DIR/kube-proxy-config-$NODE_IP.yaml.template
	sed -i 's/\(scp -P $SSH_PORT -P $SSH_PORTnameOverride: \)[^*]*/\1'"${NODE_IP}"'/' $K8S_WORK_DIR/kube-proxy-config-$NODE_IP.yaml.template
	scp -P $SSH_PORT $K8S_WORK_DIR/kube-proxy-config-$NODE_IP.yaml.template root@$NODE_IP:$K8S_CERT_PARENT_DIR/kube-proxy-config.yaml
}
###3.分发 kube-proxy systemd unit 文件
function issue_kube_proxy_service(){
	scp -P $SSH_PORT /etc/systemd/system/kube-proxy.service root@$NODE_IP:/etc/systemd/system/
}
###4.启动 kube-proxy 服务
function start_kube_proxy(){
	ssh -p $SSH_PORT root@$NODE_IP "mkdir -p $K8S_DIR/kube-proxy"
	ssh -p $SSH_PORT root@$NODE_IP "modprobe ip_vs_rr"
	ssh -p $SSH_PORT root@$NODE_IP "systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy"
}
###5.检查启动结果
function check_kube_proxy(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl status kube-proxy"
}

function main(){
	issue_kubeconfig
	issue_kube_proxy
	issue_kube_proxy_service
	start_kube_proxy
	check_kube_proxy
	echo "=====success====="
}

main "$@"
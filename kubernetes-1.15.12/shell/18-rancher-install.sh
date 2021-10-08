#!/bin/sh
set -e
##集群搭建--为集群的安装kubernetes管理工具##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

###1.下载和分发 helm 二进制文件
function issue_helm(){
	cd $K8S_WORK_DIR
  source $K8S_BIN_DIR/environment.sh
	tar -zxvf $DIRNAME/helm-v3.7.0-linux-amd64.tar

	#分发二进制文件到所有 worker 节点：
	for node_ip in ${WOKER_IPS[@]}
	  do
		echo ">>> ${node_ip}"
		scp -P $SSH_PORT linux-amd64/helm  root@${node_ip}:$K8S_BIN_DIR/
		ssh -p $SSH_PORT root@${node_ip} "chmod +x $K8S_BIN_DIR/*"
		ssh -p $SSH_PORT root@${node_ip} "helm repo add rancher-stable https://releases.rancher.com/server-charts/stable"
		ssh -p $SSH_PORT root@${node_ip} "helm repo add jetstack https://charts.jetstack.io"
		ssh -p $SSH_PORT root@${node_ip} "helm repo update"

	  done
}

###2.创建命名空间
function create_namespace(){
  kubectl create namespace cattle-system
  kubectl create namespace cert-manager
}

###3. 执行cert_manager
function exec_cert_manager() {
  cd $K8S_WORK_DIR
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.crds.yaml
  helm install cert-manager $DIRNAME/cert-manager-v0.15.0.tgz --namespace cert-manager
}

###4.检查启动结果
function check_cert_manager(){
	echo "检查启动结果 "
	echo "等待15s"
	sleep 15
	kubectl get pods --namespace cert-manager
}

function create_rancher() {
cd $K8S_WORK_DIR
cat > rancher.yml <<EOF
replicas: 1
hostname: "rancher.test.zolaq.net" #需要修改

ingress:
  tls:
    source: secret
  extraAnnotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
EOF
}

###5.执行rancher
function exec_rancher_install() {
  cd $K8S_WORK_DIR
  helm upgrade -i  rancher $DIRNAME/rancher-2.4.16.tgz -f rancher.yml --namespace cattle-system
}

###6.检查启动结果
function check_rancher() {
  echo "检查启动结果 "
	set +e
	TEM_CSR=$(kubectl get pods --namespace cattle-system | grep rancher | grep Running | awk '{print $1}')
	set -e
	COUNT=20
	while [ ! -n "$TEM_CSR" ] && [ $COUNT -gt 0 ]
	do
		sleep 5
		COUNT=$[COUNT-1]
		echo "===未查询到rancher 状态：Running，尝试重新查询$COUNT==="
		TEM_CSR=$(kubectl get pods --namespace cattle-system | grep rancher | grep Running | awk '{print $1}')
	done
}

function main(){
	issue_helm
	create_namespace
	exec_cert_manager
	check_cert_manager
	exec_rancher_install
	check_rancher
	echo "=====success====="
}
main "$@"
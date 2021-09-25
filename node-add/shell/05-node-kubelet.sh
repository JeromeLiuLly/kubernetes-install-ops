#!/bin/sh

set -e
DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

####为node节点部署 kubelet 组件####

###===在master节点上执行===###

###1.拷贝二进制文件到$NODE_IP节点
function issue_binary(){
	scp -P $SSH_PORT $K8S_BIN_DIR/{kube-proxy,kubectl,kubelet} root@$NODE_IP:$K8S_BIN_DIR/
}
###2.创建 kubelet bootstrap kubeconfig 文件
function create_bootstrap_kubeconfig(){
	# 创建 token
	export BOOTSTRAP_TOKEN=$(kubeadm token create \
	 --description kubelet-bootstrap-token \
	 --groups system:bootstrappers:$WORK_NAME \
	 --kubeconfig ~/.kube/config)

	# 设置集群参数
	kubectl config set-cluster kubernetes \
	 --certificate-authority=$K8S_CERT_DIR/ca.pem \
	 --embed-certs=true \
	 --server=https://127.0.0.1:8443 \
	 --kubeconfig=$K8S_WORK_DIR/kubelet-bootstrap-$NODE_IP.kubeconfig

	# 设置客户端认证参数，注意--token的值是第一步中定义的BOOTSTRAP_TOKEN的值。
	kubectl config set-credentials kubelet-bootstrap \
	 --token=${BOOTSTRAP_TOKEN} \
	 --kubeconfig=$K8S_WORK_DIR/kubelet-bootstrap-$NODE_IP.kubeconfig

	# 设置上下文参数
	kubectl config set-context default \
	 --cluster=kubernetes \
	 --user=kubelet-bootstrap \
	 --kubeconfig=$K8S_WORK_DIR/kubelet-bootstrap-$NODE_IP.kubeconfig

	# 设置默认上下文
	kubectl config use-context default --kubeconfig=$K8S_WORK_DIR/kubelet-bootstrap-$NODE_IP.kubeconfig

}

###3.查看 kubeadm 为$NODE_IP节点创建的 token
###4.确认token
###5.查看 token 关联的 Secret
###6.分发 bootstrap-kubeconfig 文件到$NODE_IP节点
function issue_bootstrap_kubeconfig(){
	scp -P $SSH_PORT $K8S_WORK_DIR/kubelet-bootstrap-$NODE_IP.kubeconfig root@$NODE_IP:$K8S_CERT_PARENT_DIR/kubelet-bootstrap.kubeconfig
}
###7.分发 kubelet 参数配置文件
function issue_kubelet_config(){
	cp $K8S_CERT_PARENT_DIR/kubelet-config.yaml $K8S_WORK_DIR/kubelet-config-$NODE_IP.yaml
	sed -i 's/\(address: \)[^*]*/\1"'"${IPADDR}"'"/' $K8S_WORK_DIR/kubelet-config-$NODE_IP.yaml
	sed -i 's/\(healthzBindAddress: \)[^*]*/\1"'"${IPADDR}"'"/' $K8S_WORK_DIR/kubelet-config-$NODE_IP.yaml
	scp -P $SSH_PORT $K8S_WORK_DIR/kubelet-config-$NODE_IP.yaml root@$NODE_IP:$K8S_CERT_PARENT_DIR/kubelet-config.yaml
}
###8.分发 kubelet systemd unit 文件
function issue_kubelet_service(){
	cp /etc/systemd/system/kubelet.service $K8S_WORK_DIR/kubelet-$NODE_IP.service
	sed -i 's/\(hostname-override=\)[^*]*/\1'"${NODE_IP}"' \\/' $K8S_WORK_DIR/kubelet-$NODE_IP.service
	scp -P $SSH_PORT $K8S_WORK_DIR/kubelet-$NODE_IP.service root@$NODE_IP:/etc/systemd/system/kubelet.service
}
###9.启动 kubelet 服务
function start_kubelet(){
	ssh -p $SSH_PORT root@$NODE_IP "mkdir -p ${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/"
	ssh -p $SSH_PORT root@$NODE_IP "/usr/sbin/swapoff -a"
	ssh -p $SSH_PORT root@$NODE_IP "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
}
###10.查看 kubelet 状态
function check_kubelet(){
	echo "检查kubelet.service状态："
	ssh -p $SSH_PORT root@$NODE_IP "systemctl status kubelet"
}
###11.查看节点状态
function check_nodes(){
	echo "查看node状态："
	kubectl get node
}
###12.手动 approve server cert csr
function approve_csr(){
	echo "===等待通过csr==="
	set +e
	TEM_CSR=$(kubectl get csr | grep Pending | awk '{print $1}')
	set -e
	COUNT=10
	while [ ! -n "$TEM_CSR" ] && [ $COUNT -gt 0 ]
	do
		sleep 3
		COUNT=$[COUNT-1]
		echo "===未查询到csr，尝试重新查询$COUNT==="
		TEM_CSR=$(kubectl get csr | grep Pending | awk '{print $1}')
	done
	if [ -n "$TEM_CSR" ] && [ $COUNT -ge 0 ]
	then
		kubectl certificate approve $TEM_CSR
		echo "===success==="
	else
		echo "===csr approve失败，请检查==="
	fi
}




function main(){
issue_binary
create_bootstrap_kubeconfig
issue_bootstrap_kubeconfig
issue_kubelet_config
issue_kubelet_service
start_kubelet
check_kubelet
check_nodes
approve_csr
	echo "=====success====="
}

main "$@"
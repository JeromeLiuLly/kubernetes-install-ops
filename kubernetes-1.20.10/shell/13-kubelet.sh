#!/bin/sh
set -e

##集群搭建--部署 kubelet 组件##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh


###1.创建 kubelet bootstrap kubeconfig 文件
function create_kubelet_bootstrap_kubeconfig(){

	cd $K8S_WORK_DIR
	source $K8S_BIN_DIR/environment.sh
	for (( i=0; i < ${#WOKER_HOST_NAMES[@]}; i++ ))
	  do
		node_ip=${NODE_IPS[i]}
		echo ">>> ${node_ip}"

		# 创建 token
		export BOOTSTRAP_TOKEN=$(kubeadm token create \
		  --description kubelet-bootstrap-token \
		  --groups system:bootstrappers:${WOKER_HOST_NAMES[i]} \
		  --kubeconfig ~/.kube/config)

		# 设置集群参数
		kubectl config set-cluster kubernetes \
		  --certificate-authority=$K8S_CERT_DIR/ca.pem \
		  --embed-certs=true \
		  --server=${KUBE_APISERVER} \
		  --kubeconfig=kubelet-bootstrap-${node_ip}.kubeconfig

		# 设置客户端认证参数
		kubectl config set-credentials kubelet-bootstrap \
		  --token=${BOOTSTRAP_TOKEN} \
		  --kubeconfig=kubelet-bootstrap-${node_ip}.kubeconfig

		# 设置上下文参数
		kubectl config set-context default \
		  --cluster=kubernetes \
		  --user=kubelet-bootstrap \
		  --kubeconfig=kubelet-bootstrap-${node_ip}.kubeconfig

		# 设置默认上下文
		kubectl config use-context default --kubeconfig=kubelet-bootstrap-${node_ip}.kubeconfig
	  done
	  
	echo "查看 kubeadm 为各节点创建的 token："
	  kubeadm token list --kubeconfig ~/.kube/config
	  
	echo "查看各 token 关联的 Secret："
	  kubectl get secrets  -n kube-system|grep bootstrap-token
} 
  
###2.分发 bootstrap kubeconfig 文件到所有 worker 节 点
function issue_bootstrap_kubeconfig(){
cd $K8S_WORK_DIR
source $K8S_BIN_DIR/environment.sh
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp -P $SSH_PORT kubelet-bootstrap-${node_ip}.kubeconfig root@${node_ip}:$K8S_CERT_PARENT_DIR/kubelet-bootstrap.kubeconfig
  done
}

###3.创建和分发 kubelet 参数配置文件
function issue_kubelet_config(){
	cd $K8S_WORK_DIR
	source $K8S_BIN_DIR/environment.sh

	#创建 kubelet 参数配置文件模板：
	cat > kubelet-config.yaml.template <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: "##NODE_IP##"
staticPodPath: ""
syncFrequency: 1m
fileCheckFrequency: 20s
httpCheckFrequency: 20s
staticPodURL: ""
port: 10250
readOnlyPort: 0
rotateCertificates: true
serverTLSBootstrap: true
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "$K8S_CERT_DIR/ca.pem"
authorization:
  mode: Webhook
registryPullQPS: 0
registryBurst: 20
eventRecordQPS: 0
eventBurst: 20
enableDebuggingHandlers: true
enableContentionProfiling: true
healthzPort: 10248
healthzBindAddress: "##NODE_IP##"
clusterDomain: "${CLUSTER_DNS_DOMAIN}"
clusterDNS:
  - "${CLUSTER_DNS_SVC_IP}"
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 1m
imageMinimumGCAge: 2m
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
volumeStatsAggPeriod: 1m
kubeletCgroups: ""
systemCgroups: ""
cgroupRoot: ""
cgroupsPerQOS: true
cgroupDriver: cgroupfs
runtimeRequestTimeout: 10m
hairpinMode: promiscuous-bridge
maxPods: 220
podCIDR: "${CLUSTER_CIDR}"
podPidsLimit: -1
resolvConf: /etc/resolv.conf
maxOpenFiles: 1000000
kubeAPIQPS: 1000
kubeAPIBurst: 2000
serializeImagePulls: false
evictionHard:
  memory.available:  "100Mi"
  nodefs.available:  "5%"
  nodefs.inodesFree: "5%"
  imagefs.available: "5%"
  imagefs.inodesFree: "5%"
evictionSoft: {}
enableControllerAttachDetach: true
failSwapOn: true
containerLogMaxSize: 20Mi
containerLogMaxFiles: 10
systemReserved: {}
kubeReserved: {}
systemReservedCgroup: ""
kubeReservedCgroup: ""
enforceNodeAllocatable: ["pods"]
EOF

#为各节点创建和分发 kubelet 配置文件：
for node_ip in ${WOKER_IPS[@]}
  do 
    echo ">>> ${node_ip}"
    sed -e "s/##NODE_IP##/${node_ip}/" kubelet-config.yaml.template > kubelet-config-${node_ip}.yaml.template
    scp -P $SSH_PORT kubelet-config-${node_ip}.yaml.template root@${node_ip}:$K8S_CERT_PARENT_DIR/kubelet-config.yaml
  done
}

###4.创建和分发 kubelet systemd unit 文件
function issue_kubelet_service(){
cd $K8S_WORK_DIR
source $K8S_BIN_DIR/environment.sh

#创建 kubelet systemd unit 文件模板：
cat > kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=${K8S_DIR}/kubelet
ExecStart=$K8S_BIN_DIR/kubelet \\
  --bootstrap-kubeconfig=$K8S_CERT_PARENT_DIR/kubelet-bootstrap.kubeconfig \\
  --cert-dir=$K8S_CERT_DIR \\
  --cni-conf-dir=/etc/cni/net.d \\
  --container-runtime=docker \\
  --container-runtime-endpoint=unix:///var/run/dockershim.sock \\
  --root-dir=${K8S_DIR}/kubelet \\
  --kubeconfig=$K8S_CERT_PARENT_DIR/kubelet.kubeconfig \\
  --config=$K8S_CERT_PARENT_DIR/kubelet-config.yaml \\
  --hostname-override=##NODE_NAME## \\
  --pod-infra-container-image=harbor.can-dao.com/images_k8s/pause-amd64:3.1 \\
  --image-pull-progress-deadline=15m \\
  --volume-plugin-dir=${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/ \\
  --logtostderr=true \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

	echo "为各节点创建和分发 kubelet systemd unit 文件："
	for node_name in ${WOKER_NAMES[@]}
	  do 
		echo ">>> ${node_name}"
		sed -e "s/##NODE_NAME##/${node_name}/" kubelet.service.template > kubelet-${node_name}.service
		scp -P $SSH_PORT kubelet-${node_name}.service root@${node_name}:/etc/systemd/system/kubelet.service
	  done
}

###5.Bootstrap Token Auth 和授予权限
function token_auth(){
	echo "Bootstrap Token Auth 和授予权限"
set +e
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers
set -e
}

###6.启动 kubelet 服务
function start_kubelet_service(){
	echo "启动 kubelet 服务"
	source $K8S_BIN_DIR/environment.sh
	for node_ip in ${WOKER_IPS[@]}
	  do
		echo ">>> ${node_ip}"
		ssh -p $SSH_PORT root@${node_ip} "mkdir -p ${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/"
		ssh -p $SSH_PORT root@${node_ip} "/usr/sbin/swapoff -a"
		ssh -p $SSH_PORT root@${node_ip} "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
	  done
	echo "等待5s"
	sleep 5
	echo "查看csr:"
	kubectl get csr

}

###7.自动 approve CSR 请求
function auto_approve_csr(){
	echo "自动 approve CSR 请求"
	cd $K8S_WORK_DIR
	cat > csr-crb.yaml <<EOF
 # Approve all CSRs for the group "system:bootstrappers"
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: auto-approve-csrs-for-group
 subjects:
 - kind: Group
   name: system:bootstrappers
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
   apiGroup: rbac.authorization.k8s.io
---
 # To let a node of the group "system:nodes" renew its own credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-client-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
   apiGroup: rbac.authorization.k8s.io
---
# A ClusterRole which instructs the CSR approver to approve a node requesting a
# serving cert matching its client cert.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: approve-node-server-renewal-csr
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/selfnodeserver"]
  verbs: ["create"]
---
 # To let a node of the group "system:nodes" renew its own server credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-server-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: approve-node-server-renewal-csr
   apiGroup: rbac.authorization.k8s.io
EOF

	kubectl apply -f csr-crb.yaml
}


###8.查看 kubelet 的情况
function see_kubelet(){
	echo "等待3s"
	sleep 3
	
	echo "csr信息:"
	kubectl get csr

	echo "node信息:"

	kubectl get nodes
}

###9.手动approve csr:
function approve_csr(){

	echo "手动approve csr:"
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
		echo "===csr approve success==="
	else
		echo "===csr approve失败，请检查==="
		exit 0;
	fi
	
	echo "手动approve csr之后的csr信息:"
	kubectl get csr

	
	for node_ip in ${WOKER_IPS[@]}
	  do
		echo ">>> ${node_ip} kubelet证书信息"
		ssh -p $SSH_PORT root@${node_ip} "ls -l $K8S_CERT_DIR/kubelet-*"
	  done
}

###10.kubelet 提供的 API 接口
function see_kubelet_api(){
echo "kubelet 提供的 API 接口"

for node_ip in ${WOKER_IPS[@]}
		  do
			echo ">>> ${node_ip}"
			ssh -p $SSH_PORT root@${node_ip} "sudo netstat -lnpt|grep kubelet"
		  done

echo "kubelet-api-admin信息"
kubectl describe clusterrole system:kubelet-api-admin

}

###11.kubelet api 认证和授权
function auth_kubelet_api(){
echo "kubelet api 认证和授权验证"

set +e
curl -s --cacert $K8S_CERT_DIR/ca.pem https://${IPADDR}:10250/metrics



curl -s --cacert $K8S_CERT_DIR/ca.pem -H "Authorization: Bearer 123456" https://${IPADDR}:10250/metrics



curl -s --cacert $K8S_CERT_DIR/ca.pem --cert $K8S_CERT_DIR/kube-controller-manager.pem --key $K8S_CERT_DIR/kube-controller-manager-key.pem https://${IPADDR}:10250/metrics
set -e
}

###12.bear token 认证和授权
function auth_bear_token(){
echo "bear token 认证和授权"
kubectl create sa kubelet-api-test

kubectl create clusterrolebinding kubelet-api-test --clusterrole=system:kubelet-api-admin --serviceaccount=default:kubelet-api-test

SECRET=$(kubectl get secrets | grep kubelet-api-test | awk '{print $1}')
TOKEN=$(kubectl describe secret ${SECRET} | grep -E '^token' | awk '{print $2}')
echo ${TOKEN}


curl -s --cacert $K8S_CERT_DIR/ca.pem -H "Authorization: Bearer ${TOKEN}" https://${IPADDR}:10250/metrics|head
}


###13.approve csr补充:
function approve_csr_again(){

	echo "approve csr补充:"
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
		echo "===csr again approve success==="
	else
		echo "===csr again approve失败，请检查csr是否正常==="
	fi
	
	echo "补充approve csr之后的csr信息:"
	kubectl get csr

	
	for node_ip in ${WOKER_IPS[@]}
	  do
		echo ">>> ${node_ip} kubelet证书信息"
		ssh -p $SSH_PORT root@${node_ip} "ls -l $K8S_CERT_DIR/kubelet-*"
	  done
}

function main(){
	create_kubelet_bootstrap_kubeconfig
	issue_bootstrap_kubeconfig
	issue_kubelet_config
	issue_kubelet_service
	token_auth
	start_kubelet_service
	auto_approve_csr
	see_kubelet
	approve_csr
	see_kubelet_api
	auth_kubelet_api
	auth_bear_token
	#最后node添加进来了 还需要approve一次
	approve_csr_again
	echo "=====success====="
}

main "$@"

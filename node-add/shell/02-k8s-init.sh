#!/bin/sh

set -e
DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh
####分发相关文件到新增节点中，在master节点中执行

###B.开启免密登录新节点
function login_node(){
	echo "按提示输入$IPADDR的root用户密码"
	ssh-copy-id -o StrictHostKeyChecking=no -p $SSH_PORT root@$NODE_IP
	ssh -p $SSH_PORT root@$NODE_IP "cat /etc/hostname"
}

###C.分发sh文件到其他节点,并初始化机器
function issue_sh_and_init(){
	for node_ip in ${NODE_IPS[@]}
  do
     (
      (
        echo ">>> ${node_ip}"
        ssh -p $SSH_PORT root@${node_ip} "mkdir -p $K8S_BIN_DIR"
        ssh -p $SSH_PORT root@${node_ip} "mkdir -p $K8S_WORK_DIR"
        ssh -p $SSH_PORT root@${node_ip} "mkdir -p $K8S_CERT_DIR"
        scp -P $SSH_PORT $DIRNAME/00-environment.sh root@$node_ip:$K8S_BIN_DIR/environment.sh
        scp -P $SSH_PORT $DIRNAME/00-environment.sh root@$node_ip:$K8S_WORK_DIR/00-environment.sh
        scp -P $SSH_PORT $DIRNAME/system-init.sh root@$node_ip:$K8S_WORK_DIR/system-init.sh
        scp -P $SSH_PORT $DIRNAME/kernel-lt-devel-5.4.104-1.el7.elrepo.x86_64.rpm root@$node_ip:$K8S_WORK_DIR/kernel-lt-devel-5.4.104-1.el7.elrepo.x86_64.rpm
        scp -P $SSH_PORT $DIRNAME/kernel-lt-5.4.104-1.el7.elrepo.x86_64.rpm root@$node_ip:$K8S_WORK_DIR/kernel-lt-5.4.104-1.el7.elrepo.x86_64.rpm
        ssh -p $SSH_PORT root@${node_ip} "chmod +x $K8S_WORK_DIR/*.sh"

        ssh -p $SSH_PORT root@${node_ip} "cd $K8S_WORK_DIR && sh system-init.sh"
      )  || echo -e "\033[31m分发文件出现错误\033[0m"
    )  | sed "s/^/[${node_ip}] /g" &
  done

  wait
}

###1. 分发ca证书文件
function issue_ca(){
	scp -P $SSH_PORT $K8S_CERT_DIR/ca*.pem $K8S_CERT_DIR/ca-config.json root@$NODE_IP:$K8S_CERT_DIR
}

###2. 分发kubectl二进制文件
function issue_kubectl(){
	scp -P $SSH_PORT $K8S_BIN_DIR/kubectl root@$NODE_IP:$K8S_BIN_DIR
	ssh -p $SSH_PORT root@$NODE_IP "chmod +x $K8S_BIN_DIR/*"
}

###3. 分发 kubeconfig 文件
function issue_kubeconfig(){
	ssh -p $SSH_PORT root@$NODE_IP "mkdir -p ~/.kube"
	scp -P $SSH_PORT ~/.kube/config root@$NODE_IP:~/.kube/config
}

###4. 分发 flanneld 二进制文件
function issue_flanneld(){
	scp -P $SSH_PORT $K8S_BIN_DIR/{flanneld,mk-docker-opts.sh} root@$NODE_IP:$K8S_BIN_DIR/ 
	ssh -p $SSH_PORT root@$NODE_IP "chmod +x $K8S_BIN_DIR/*"
}

###5.分发flanneld证书跟私钥
function issue_flanneld_cert(){
	ssh -p $SSH_PORT root@$NODE_IP "mkdir -p $FLANNEL_CERT_DIR"
	scp -P $SSH_PORT $FLANNEL_CERT_DIR/flanneld*.pem root@$NODE_IP:$FLANNEL_CERT_DIR
}

###6.分发 flanneld systemd unit 文件
function issue_flanneld_service(){
	scp -P $SSH_PORT /etc/systemd/system/flanneld.service root@$NODE_IP:/etc/systemd/system/
}

###7. 启动 flanneld 服务
function start_flanneld(){
	ssh -p $SSH_PORT root@$NODE_IP "systemctl daemon-reload && systemctl enable flanneld && systemctl restart flanneld"
	ssh -p $SSH_PORT root@$NODE_IP "systemctl status flanneld"
}


function main(){
	login_node
	issue_sh_and_init
	issue_ca
	issue_kubectl
	issue_kubeconfig
	issue_flanneld
	issue_flanneld_cert
	issue_flanneld_service
	start_flanneld
	echo "=====success====="
	echo "=====系统初始化完成，需要重启${NODE_IP}====="
}

main "$@"
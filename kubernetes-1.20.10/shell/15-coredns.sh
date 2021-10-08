#!/bin/sh
set -e
##集群搭建--部署coredns插件##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh
source $K8S_BIN_DIR/environment.sh

###1.解压文件
function unzip_file(){
	cd $K8S_WORK_DIR/kubernetes/
	tar -xzvf kubernetes-src.tar.gz cluster/addons/dns/coredns
}
###2.修改重要参数
function update_config(){
	cd $K8S_WORK_DIR/kubernetes/cluster/addons/dns/coredns
	cp coredns.yaml.base coredns.yaml
	sed -i -e "s/__PILLAR__DNS__DOMAIN__/${CLUSTER_DNS_DOMAIN}/" -e "s/__PILLAR__DNS__SERVER__/${CLUSTER_DNS_SVC_IP}/" coredns.yaml
	sed -i -e "s/__PILLAR__DNS__MEMORY__LIMIT__/200Mi/" coredns.yaml
	#修改镜像地址
	sed -i "s/k8s.gcr.io/reg.can-dao.com\/library/" coredns.yaml
	#设置node节点label为master03
	#sed -i "s/beta.kubernetes.io\/os: linux/label-test: label-test/" coredns.yaml
}

###3.拷贝coredns.yaml到指定目录
function copy_yaml(){
    mkdir -p $YAML_DIR/kubernetes-coredns
	cp $K8S_WORK_DIR/kubernetes/cluster/addons/dns/coredns/coredns.yaml $YAML_DIR/kubernetes-coredns/
}

###3.创建coredns
function create_coredns(){

	kubectl create -f $YAML_DIR/kubernetes-coredns/coredns.yaml

	echo "检查kube-system相关内容"
	kubectl get all -n kube-system
	
	echo "需要到容器内验证是否可以访问域名"
}

function main(){
	unzip_file
	update_config
	copy_yaml
	create_coredns
	echo "====success===="
}

main "$@"
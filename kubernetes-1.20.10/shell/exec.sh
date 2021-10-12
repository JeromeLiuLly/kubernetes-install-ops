#!/bin/bash

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

function init_ca(){
  echo "执行------ 02-ca.sh --begin---"
  sh $DIRNAME/02-ca.sh
  echo "执行------ 02-ca.sh --end---"
}

function init_kubectl(){
  echo "执行------ 03-kubectl.sh --begin---"
  sh $DIRNAME/03-kubectl.sh
  echo "执行------ 03-kubectl.sh --end---"
}

function init_etcd(){
  echo "执行------ 04-etcd.sh --begin---"
  sh $DIRNAME/04-etcd.sh
  echo "执行------ 04-etcd.sh --end---"
}

function init_flannel(){
  echo "执行------ 05-flannel.sh --begin---"
  sh $DIRNAME/05-flannel.sh
  echo "执行------ 05-flannel.sh --end---"
}

function init_apiserver_nginx(){
  echo "执行------ 06-apiserver-nginx.sh --begin---"
  sh $DIRNAME/06-apiserver-nginx.sh
  echo "执行------ 06-apiserver-nginx.sh --end---"
}

function init_master(){
  echo "执行------ 07-master-init.sh --begin---"
  sh $DIRNAME/07-master-init.sh
  echo "执行------ 07-master-init.sh --end---"
}

function init_apiserver(){
  echo "执行------ 08-apiserver.sh --begin---"
  sh $DIRNAME/08-apiserver.sh
  echo "执行------ 08-apiserver.sh --end---"
}

function init_controller_manager(){
  echo "执行------ 09-controller-manager.sh --begin---"
  sh $DIRNAME/09-controller-manager.sh
  echo "执行------ 09-controller-manager.sh --end---"
}

function init_scheduler(){
  echo "执行------ 10-scheduler.sh --begin---"
  sh $DIRNAME/10-scheduler.sh
  echo "执行------ 10-scheduler.sh --end---"
}

function init_work(){
  echo "执行------ 11-worker-init.sh --begin---"
  sh $DIRNAME/11-worker-init.sh
  echo "执行------ 11-worker-init.sh --end---"
}

function init_docker(){
  echo "执行------ 12-docker.sh --begin---"
  sh $DIRNAME/12-docker.sh
  echo "执行------ 12-docker.sh --end---"
}

function init_kubelet(){
  echo "执行------ 13-kubelet.sh --begin---"
  sh $DIRNAME/13-kubelet.sh
  echo "执行------ 13-kubelet.sh --end---"
}

function init_kube_proxy(){
  echo "执行------ 14-kube-proxy.sh --begin---"
  sh $DIRNAME/14-kube-proxy.sh
  echo "执行------ 14-kube-proxy.sh --end---"
}

function init_coredns(){
  echo "执行------ 15-coredns.sh --begin---"
  sh $DIRNAME/15-coredns.sh
  echo "执行------ 15-coredns.sh --end---"
}

function main(){
	init_ca
	init_kubectl
	init_etcd
	init_flannel
	init_apiserver_nginx
	init_master
	init_apiserver
	init_controller_manager
	init_scheduler
	init_work
	init_docker
	init_kubelet
	init_kube_proxy
	init_coredns
	echo "=====success====="
}

main "$@"



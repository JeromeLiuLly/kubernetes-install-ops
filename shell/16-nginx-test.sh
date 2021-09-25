#!/bin/sh
set -e

##集群搭建--验证集群功能##
##author julian##
##date 2019-10-25##

#获取当前执行脚本的目录

DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh


###1.验证集群功能
function create_test_ngxin(){
cd $K8S_WORK_DIR
cat > nginx-ds.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-ds
  labels:
    app: nginx-ds
spec:
  type: NodePort
  selector:
    app: nginx-ds
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ds
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  template:
    metadata:
      labels:
        app: nginx-ds
    spec:
      containers:
      - name: my-nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
EOF



kubectl create -f nginx-ds.yml



kubectl get pods  -o wide|grep nginx-ds


kubectl get svc |grep nginx-ds

echo "若服务正常，请测试其端口以及局域网ip是否可以互相ping通"
}

function main(){
	create_test_ngxin
	echo "=====success====="
}

main "$@"


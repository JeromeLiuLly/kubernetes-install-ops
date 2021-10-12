#!/bin/sh
set -e

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
  selector:
    app: nginx-ds
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: app/v1
kind: Deployment
metadata:
  name: nginx-ds
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      app: nginx-ds
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

cat > alpine.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: alpine
spec:
  containers:
  - name: alpine
    image: reg.can-dao.com/google_containers/alpine:3.5
    command:
    - sh
    - -c
    - while true; do sleep 1; done
EOF

cat > busybox.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  #namespace: kube-system
spec:
  terminationGracePeriodSeconds: 60 ##k8s将会给应用发送SIGTERM信号，可以用来正确、优雅地关闭应用,默认为30秒
  containers:
  - image: reg.can-dao.com/google_containers/busybox:1.24
    command:
      - sleep
      - "3600"
    lifecycle:
      preStop:
        exec:
          command:
          - sh
          - -c
          - for i in \$(seq 50);do sleep 1;echo $i;done >> /etc/hosts
    imagePullPolicy: IfNotPresent
    name: busybox
  restartPolicy: Always
EOF

kubectl create -f nginx-ds.yml
kubectl create -f alpine.yml
kubectl create -f busybox.yml

kubectl get pods  -o wide|grep nginx-ds

kubectl get svc |grep nginx-ds

set +e
ClusterIP=$(kubectl get svc | grep nginx-ds | awk '{print $3}')
set -e
	COUNT=20
	while [ ! -n "ClusterIP" ] && [ $COUNT -gt 0 ]
	do
		sleep 3
		COUNT=$[COUNT-1]
		echo "===未查询到nginx-svc ，尝试重新查询$COUNT==="
		ClusterIP=$(kubectl get svc | grep nginx-ds | awk '{print $3}')
	done

curl ClusterIP
echo "若服务正常，请测试其端口以及局域网ip是否可以互相ping通"
}

function main(){
	create_test_ngxin
	echo "=====success====="
}

main "$@"


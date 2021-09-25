# 1.编辑 cluster.yml 配置文件
```yaml
base:
  # (可选) 存放yaml文件的目录 默认值: /home/kube-yaml
  yaml_dir: /home/kube-yaml
  # (可选) 自定义的 hosts
  custom_hosts:
    - host: 192.168.20.100
      name: reg.xxx.com
ssh:
  # (可选) ssh端口号 默认值: 22
  port: 920
nodes:
  #暂时只支持每次新增一个节点
  - address: 192.168.20.20
    hostname_override: node-1
    role:
      - worker
      
service:
  k8s:
    # (可选) k8s 各组件数据 目录 默认值: /data/k8s/k8s
    dir: /data/k8s/k8s
    # (可选) k8s 工作 目录 默认值: /data/k8s/work
    work_dir: /data/k8s/work
    # (可选) k8s bin 目录 目录 默认值: /usr/local/bin/
    bin_dir: /usr/local/bin/
    # (可选) k8s 数据父目录 默认值: /etc/kubernetes
    cert_parent_dir: /etc/kubernetes
    # (可选) k8s 证书 目录 默认值: /etc/kubernetes/cert
    cert_dir: /etc/kubernetes/cert
  kube_nginx:
    # (可选) kube-nginx软件目录 默认值: /usr/local/kube-nginx
    dir: /usr/local/kube-nginx
  flanneld:
    # (可选) 节点间互联网络接口名称
    iface: eth0
    # (可选) flanneld 证书 目录 默认值: /etc/flanneld/cert
    cert_dir: /etc/flanneld/cert
    # (可选) flanneld 网络配置前缀 默认值: /k8s/network
    etcd_prefix: /k8s/network
  docker:
    # (可选) docker 数据目录 默认值: /data/k8s/docker
    dir: /data/k8s/docker
```

# 2.运行初始化脚本
```shell
# 一般情况下我们会选择 /data/k8s/work/ 作为我们的工作目录
cd /data/k8s/work/
# 注意：当前目录下必须存在 cluster.yml
sh -c "$(curl -fsSL https://saas-plus.oss-cn-shanghai.aliyuncs.com/aod/node-add/init.sh)" 
```

# 3.按步骤执行脚本

02-k8s-init.sh

03-node-docker.sh

04-kube-apiserver-nginx.sh

05-node-kubelet.sh

06-node-kube-proxy.sh

07-node-role-label.sh

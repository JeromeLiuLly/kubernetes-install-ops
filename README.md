# 1.编辑 cluster.yml 配置文件
```yaml
base:
  # (可选) 存放yaml文件的目录 默认值: /home/kube-yaml
  yaml_dir: /home/kube-yaml
  # (可选) CA证书有效时间 默认值: 87600h(10年)
  ca_cert_date: 87600h
  # (可选) CA证书有效时间 默认值: 87600h(10年)
  cert_date: 87600h
  # (可选) 自定义的 hosts
  custom_hosts:
    - host: 192.168.20.100
      name: reg.xxx.com
ssh:
  # (可选) ssh端口号 默认值: 22
  port: 920
nodes:
  - address: 192.168.20.20
    hostname_override: node-1
    role:
      - controlplane
      - etcd
      - worker
  - address: 192.168.20.21
    hostname_override: node-2
    role:
      - worker
  - address: 192.168.20.22
    hostname_override: node-3
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
    # (可选) 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证) 默认值: 10.254.0.0/16
    service_cidr: 10.254.0.0/16
    # (可选) Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证) 默认值: 10.226.0.0/16
    cluster_cidr: 10.226.0.0/16
    # (可选) 服务端口范围 (NodePort Range) 默认值: 30000-32767
    node_port_range: 30000-32767
    # (可选) kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP)
    cluster_kubernetes_svc_ip: 10.254.0.1
    # (可选) 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配) 默认值: 10.254.0.2
    cluster_dns_svc_ip: 10.254.0.2
    # (可选) 集群 DNS 域名（末尾不带点号） 默认值: cluster.local
    cluster_dns_domain: cluster.local
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
  etcd:
    # (可选) etcd 证书 目录 默认值: /etc/etcd/cert
    cert_dir: /etc/etcd/cert
    # (可选) etcd 数据目录 默认值: /data/k8s/etcd/data
    data_dir: /data/k8s/etcd/data
    # (可选) etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区 默认值: /data/k8s/etcd/wal
    wal_dir: /data/k8s/etcd/wal
```

# 2.运行初始化脚本
```shell
# 一般情况下我们会选择 /data/k8s/work/ 作为我们的工作目录
cd /data/k8s/work/
# 注意：当前目录下必须存在 cluster.yml
sh -c "$(curl -fsSL https://saas-plus.oss-cn-shanghai.aliyuncs.com/aod/shell/init.sh)" 
```

# 3.按步骤执行脚本
00-environment.sh

01-1-system-init.sh(需要重启服务器)

01-2-pwd-login.sh

01-3-copy-env.sh

01-4-passwd-dev_dc.sh(可选)

02-ca.sh

03-kubectl.sh

04-etcd.sh

05-flannel.sh

06-apiserver-nginx.sh

07-master-init.sh

08-apiserver.sh

09-controller-manager.sh

10-scheduler.sh

11-worker-init.sh

12-docker.sh

13-kubelet.sh

14-kube-proxy.sh

15-coredns.sh

16-nginx-test.sh

17-node-role-label.sh

###### 以下步骤按需操作
18-node-role-label.sh

19-node-role-label.sh

#!/usr/bin/bash
set -e

# 初始化脚本
# 1.先根据配置文件生成出 00-environment.sh
# 2.提前下载所需要的包

# 获取当前目录
DIRNAME=$(cd "$(dirname "$0")";pwd)

cluster_yaml="${DIRNAME}/cluster.yml"

if [ ! -f "$cluster_yaml" ]; then
    echo "当前目录不存在 cluster.yml"
    exit 1
fi

# 全局域名
RESOUECE_URL="https://kubenetes-ops.oss-cn-shanghai.aliyuncs.com/kubernetes-1.20.10/"

# yq 资源地址
RESOURCE_YQ_URL=$RESOUECE_URL"yq"

# KUBERNETES 资源地址
RESOURCE_KUBERNETES_SERVER_URL=$RESOUECE_URL"kubernetes-server-linux-amd64.tar.gz"
RESOURCE_KUBERNETES_CLIENT_URL=$RESOUECE_URL"kubernetes-client-linux-amd64.tar.gz"

# flannel 资源地址
RESOURCE_FLANNEL_URL=$RESOUECE_URL"flannel-v0.11.0-linux-amd64.tar.gz"

# etcd 资源地址
RESOURCE_ETCD_URL=$RESOUECE_URL"etcd-v3.3.13-linux-amd64.tar.gz"

# docker 资源地址
RESOURCE_DOCKER_URL=$RESOUECE_URL"docker-18.09.6.tgz"

# nginx 资源地址
RESOURCE_NGINX_URL=$RESOUECE_URL"nginx-1.15.3.tar.gz"

# helm 资源地址
RESOURCE_HELM_URL=$RESOUECE_URL"helm-v3.7.0-linux-amd64.tar"

# rancher 资源地址
RESOURCE_RANCHER_URL=$RESOUECE_URL"rancher-2.5.9.tgz"

# cert-manager 资源地址
RESOURCE_CERT_MANAGER_URL=$RESOUECE_URL"cert-manager-v0.15.0.tgz"

# cert-manager 资源地址
RESOURCE_TRAEFIK_URL=$RESOUECE_URL"traefik-9.20.1.tgz"

# soft 资源地址
SOFT_URLS=(
$RESOUECE_URL"kernel-lt-5.4.104-1.el7.elrepo.x86_64.rpm"
$RESOUECE_URL"kernel-lt-devel-5.4.104-1.el7.elrepo.x86_64.rpm"
$RESOUECE_URL"cfssl-certinfo_linux-amd64"
$RESOUECE_URL"cfssljson_linux-amd64"
$RESOUECE_URL"cfssl_linux-amd64"
)

# shell 资源地址
RESOURCE_SHELL_URLS=(
$RESOUECE_URL"shell/system-init.sh"
$RESOUECE_URL"shell/passwd-dev_dc.sh"
$RESOUECE_URL"shell/01-1-pwd-login.sh"
$RESOUECE_URL"shell/01-2-copy-and-init.sh"
$RESOUECE_URL"shell/02-ca.sh"
$RESOUECE_URL"shell/03-kubectl.sh"
$RESOUECE_URL"shell/04-etcd.sh"
$RESOUECE_URL"shell/05-flannel.sh"
$RESOUECE_URL"shell/06-apiserver-nginx.sh"
$RESOUECE_URL"shell/07-master-init.sh"
$RESOUECE_URL"shell/08-apiserver.sh"
$RESOUECE_URL"shell/09-controller-manager.sh"
$RESOUECE_URL"shell/10-scheduler.sh"
$RESOUECE_URL"shell/11-worker-init.sh"
$RESOUECE_URL"shell/12-docker.sh"
$RESOUECE_URL"shell/13-kubelet.sh"
$RESOUECE_URL"shell/14-kube-proxy.sh"
$RESOUECE_URL"shell/15-coredns.sh"
$RESOUECE_URL"shell/16-nginx-test.sh"
$RESOUECE_URL"shell/17-node-role-label.sh"
)

download_resource(){
  RESOURCE_URL="$1"
  RESOURCE_FILENAME="$2"
  if  [ ! -n "$RESOURCE_FILENAME" ] ;then
      RESOURCE_FILENAME=${RESOURCE_URL##*/}
  fi
  http_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} "${RESOURCE_URL}")
  if [ "$http_code" -ge "200" ]&&[ "$http_code" -lt "300" ];then
      # 判断文件是否存在 而且是否和需要下载的大小的一致
      if [ -f "$RESOURCE_FILENAME" ]; then
          local_file_length=$(ls -l "$RESOURCE_FILENAME" | awk '{print $5}')
          server_file_length=$(curl -sI "$RESOURCE_URL" | grep -i Content-Length | awk '{print $2}' | sed 's/\r//')
          if [ $local_file_length -eq $server_file_length ];then
              echo "${RESOURCE_FILENAME}已经存在"
              return
          fi
      fi

      echo "正在下载 ${RESOURCE_FILENAME}"
      curl -o "$RESOURCE_FILENAME" -# "${RESOURCE_URL}"
      echo "下载 ${RESOURCE_FILENAME} 完成"
  else
      echo "资源地址有误，状态码为 $http_code ,url: ${RESOURCE_URL}"
      exit 1
  fi
}

# 先检查所需的插件
if ! type yq >/dev/null 2>&1; then
    echo 'yq 未安装,现在将自动安装yq';
    download_resource "${RESOURCE_YQ_URL}" "yq"
    chmod +x yq && mv yq /usr/local/bin/yq
    echo 'yq 安装完成';
fi

# 下载需要的包
download_resource "${RESOURCE_KUBERNETES_SERVER_URL}"
download_resource "${RESOURCE_KUBERNETES_CLIENT_URL}"
download_resource "${RESOURCE_FLANNEL_URL}"
download_resource "${RESOURCE_ETCD_URL}"
download_resource "${RESOURCE_DOCKER_URL}"
download_resource "${RESOURCE_NGINX_URL}"
download_resource "${RESOURCE_HELM_URL}"
download_resource "${RESOURCE_RANCHER_URL}"
download_resource "${RESOURCE_CERT_MANAGER_URL}"
download_resource "${RESOURCE_TRAEFIK_URL}"

# 检查 IP 地址
fun_check_ip_address(){
  echo $1|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null;
  #IP地址必须为全数字
  if [ $? -ne 0 ]
  then
    return 1
  fi
  ipaddr=$1
  a=`echo $ipaddr|awk -F . '{print $1}'`  #以"."分隔，取出每个列的值
  b=`echo $ipaddr|awk -F . '{print $2}'`
  c=`echo $ipaddr|awk -F . '{print $3}'`
  d=`echo $ipaddr|awk -F . '{print $4}'`
  for num in $a $b $c $d
  do
    if [ $num -gt 255 ] || [ $num -lt 0 ]    #每个数值必须在0-255之间
    then
      return 1
    fi
  done
  return 0
}

# (可选) 存放yaml文件的目录 默认值: /home/kube-yaml
base_yaml_dir=$(yq eval ".base.yaml_dir // \"/home/kube-yaml\"" ${cluster_yaml})
# (可选) CA证书有效时间 默认值: 87600h(10年)
base_ca_cert_date=$(yq eval ".base.ca_cert_date // \"87600h\"" ${cluster_yaml})
# (可选) CA证书有效时间 默认值: 87600h(10年)
base_cert_date=$(yq eval ".base.cert_date // \"87600h\"" ${cluster_yaml})

# (可选) k8s 各组件数据 目录 默认值: /data/k8s/k8s
service_k8s_dir=$(yq eval ".service.k8s.dir // \"/data/k8s/k8s\"" ${cluster_yaml})
# (可选) k8s 工作 目录 默认值: /data/k8s/work
service_k8s_work_dir=$(yq eval ".service.k8s.work_dir // \"/data/k8s/work\"" ${cluster_yaml})
# (可选) k8s bin 目录 目录 默认值: /usr/local/bin/
service_k8s_bin_dir=$(yq eval ".service.k8s.bin_dir // \"/usr/local/bin/\"" ${cluster_yaml})
# (可选) k8s 数据父目录 默认值: /etc/kubernetes
service_k8s_cert_parent_dir=$(yq eval ".service.k8s.cert_parent_dir // \"/etc/kubernetes\"" ${cluster_yaml})
# (可选) k8s 证书 目录 默认值: /etc/kubernetes/cert
service_k8s_cert_dir=$(yq eval ".service.k8s.cert_dir // \"/etc/kubernetes/cert\"" ${cluster_yaml})
# (可选) 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证) 默认值: 10.254.0.0/16
service_k8s_service_cidr=$(yq eval ".service.k8s.service_cidr // \"10.254.0.0/16\"" ${cluster_yaml})
# (可选) Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证) 默认值: 10.226.0.0/16
service_k8s_cluster_cidr=$(yq eval ".service.k8s.cluster_cidr // \"10.226.0.0/16\"" ${cluster_yaml})
# (可选) 服务端口范围 (NodePort Range) 默认值: 30000-32767
service_k8s_node_port_range=$(yq eval ".service.k8s.node_port_range // \"30000-32767\"" ${cluster_yaml})
# # (可选) kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP) 默认值: 10.254.0.1
service_k8s_cluster_kubernetes_svc_ip=$(yq eval ".service.k8s.cluster_kubernetes_svc_ip // \"10.254.0.1\"" ${cluster_yaml})
# (可选) 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配) 默认值: 10.254.0.2
service_k8s_cluster_dns_svc_ip=$(yq eval ".service.k8s.cluster_dns_svc_ip // \"10.254.0.2\"" ${cluster_yaml})
# (可选) 集群 DNS 域名（末尾不带点号） 默认值: cluster.local
service_k8s_cluster_dns_domain=$(yq eval ".service.k8s.cluster_dns_domain // \"cluster.local\"" ${cluster_yaml})

# (可选) kube-nginx 软件目录 默认值: /usr/local/kube-nginx
service_kube_nginx_dir=$(yq eval ".service.kube_nginx.dir // \"/usr/local/kube-nginx\"" ${cluster_yaml})

# (可选) 节点间互联网络接口名称 默认值: eth0
service_flanneld_iface=$(yq eval ".service.flanneld.iface // \"eth0\"" ${cluster_yaml})

# (可选) flanneld 证书 目录 默认值: /etc/flanneld/cert
service_flanneld_cert_dir=$(yq eval ".service.flanneld.cert_dir // \"/etc/flanneld/cert\"" ${cluster_yaml})

# (可选) flanneld 网络配置前缀 默认值: /k8s/network
service_flanneld_etcd_prefix=$(yq eval ".service.flanneld.etcd_prefix // \"/k8s/network\"" ${cluster_yaml})

# (可选) docker 数据目录 默认值: /data/k8s/docker
service_docker_dir=$(yq eval ".service.docker.dir // \"/data/k8s/docker\"" ${cluster_yaml})

# (可选) etcd 证书 目录 默认值: /etc/etcd/cert
service_etcd_cert_dir=$(yq eval ".service.etcd.cert_dir // \"/etc/etcd/cert\"" ${cluster_yaml})
# (可选) etcd 数据目录 默认值: /data/k8s/etcd/data
service_etcd_data_dir=$(yq eval ".service.etcd.data_dir // \"/data/k8s/etcd/data\"" ${cluster_yaml})
# (可选) etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区 默认值: /data/k8s/etcd/wal
service_etcd_wal_dir=$(yq eval ".service.etcd.wal_dir // \"/data/k8s/etcd/wal\"" ${cluster_yaml})

# 解析 ssh 的账号和端口
ssh_user=$(yq eval ".ssh.user // \"root\"" ${cluster_yaml})
ssh_port=$(yq eval ".ssh.port // \"22\"" ${cluster_yaml})

nodes=($(yq eval '.nodes[].address' ${cluster_yaml}))
custom_hosts_names=($(yq eval '.base | .custom_hosts[].name // []' ${cluster_yaml}))

# 检查节点数
if [[ ! ${#nodes[@]} -gt 0 ]]; then
  echo "节点数为 0"
  exit 1
fi

exist_node=()
for ((i = 0; i < ${#nodes[@]}; i++))
do
  node_ip=${nodes[$i]}

  # 检查 IP 地址是否合法
  fun_check_ip_address ${node_ip}
  if [ $? -ne 0 ] ;then
    echo "节点IP地址有误[${node_ip}]"
    exit 1
  fi

  if  [[ ! "${exist_node[@]}" =~ "${node_ip}" ]] ;then
    # 不存在当前node的话就记录一下
    exist_node[${#exist_node[*]}]=${node_ip}
  else
    echo "存在重复的节点[${node_ip}]"
    exit 1
  fi
done

if [ $? -ne 0 ] ;then
  exit 1
fi

# 检查自定义的 host
exist_custom_hosts_names=()
for ((i = 0; i < ${#custom_hosts_names[@]}; i++))
do

  custom_hosts_name=${custom_hosts_names[$i]}
  custom_hosts_host=$(yq eval ".base | .custom_hosts[] | select(.name == \"${custom_hosts_name}\") | .host" ${cluster_yaml})

  node_ip=${custom_hosts_host}

  # 检查 IP 地址是否合法
  fun_check_ip_address ${node_ip}
  if [ $? -ne 0 ] ;then
    echo "自定义的 hosts ${custom_hosts_name} host有误[${node_ip}]"
    exit 1
  fi

  if  [[ ! "${exist_custom_hosts_names[@]}" =~ "${custom_hosts_name}" ]] ;then
    # 不存在当前node的话就记录一下
    exist_custom_hosts_names[${#exist_custom_hosts_names[*]}]=${custom_hosts_name}
  else
    echo "存在重复的自定义的 hosts [${custom_hosts_name}]"
    exit 1
  fi
done

if [ $? -ne 0 ] ;then
  exit 1
fi

HOSTS=()
WOKER_HOST_NAMES=()

controlplane_node=()
etcd_node=()
worker_node=()

for ((i = 0; i < ${#nodes[@]}; i++))
do
  echo "读取节点 $i --> ${nodes[$i]}"

  # 获取 IP 地址
  address="$(yq eval ".nodes[$i].address" ${cluster_yaml})"

  # 获取重写的 hostname
  hostname_override="$(yq eval ".nodes[$i].hostname_override" ${cluster_yaml})"

  HOSTS[${#HOSTS[*]}]="${nodes[$i]}=${hostname_override}"
  WOKER_HOST_NAMES[${#WOKER_HOST_NAMES[*]}]=${hostname_override}

  # 获取节点角色
  role_array=($(yq eval ".nodes[$i].role[]" ${cluster_yaml}))

  for role in ${role_array[@]};
  do
    if [[ "${role}" == "controlplane" ]]; then
      echo "节点[$i]拥有角色 -> controlplane"
      controlplane_node[${#controlplane_node[*]}]=${nodes[$i]}
    elif [[ "${role}" == "etcd" ]]; then
      echo "节点[$i]拥有角色 -> etcd"
      etcd_node[${#etcd_node[*]}]=${nodes[$i]}
    elif [[ "${role}" == "worker" ]]; then
      echo "节点[$i]拥有角色 -> worker"
      worker_node[${#worker_node[*]}]=${nodes[$i]}
    else
      echo "配置错误[${role}]"
      exit 1
    fi
  done

  echo "address -> ${address}"
  echo "hostname_override -> ${hostname_override}"
  echo "roles -> ${role_array[@]}"

done

for ((i = 0; i < ${#custom_hosts_names[@]}; i++))
do
  custom_hosts_name=${custom_hosts_names[$i]}
  custom_hosts_host=$(yq eval ".base | .custom_hosts[] | select(.name == \"${custom_hosts_name}\") | .host" ${cluster_yaml})
  HOSTS[${#HOSTS[*]}]="${custom_hosts_host}=${custom_hosts_name}"
done

# 检查 controlplane 数量
if [[ ! ${#controlplane_node[@]} -gt 0 ]]; then
  echo "controlplane 的数量不能为 0"
  exit 1
fi

# 检查 etcd 数量
if [[ ! ${#etcd_node[@]} -gt 0 ]]; then
  echo "etcd 的数量不能为 0"
  exit 1
fi

# 检查 worker 数量
if [[ ! ${#worker_node[@]} -gt 0 ]]; then
  echo "worker 的数量不能为 0"
  exit 1
fi

NODE_IPS=()
NODE_NAMES=()
for ((i = 0; i < ${#controlplane_node[@]}; i++))
do
  node_ip=${controlplane_node[$i]}

  if  [[ ! "${NODE_IPS[@]}" =~ "${node_ip}" ]] && [[ "${worker_node[@]}" =~ "${node_ip}" ]];then
    NODE_IPS[${#NODE_IPS[*]}]=${node_ip}
    NODE_NAMES[${#NODE_NAMES[*]}]=$(yq eval ".nodes[] | select(.address == \"${node_ip}\") | .hostname_override" ${cluster_yaml})
  fi
done
for ((i = 0; i < ${#etcd_node[@]}; i++))
do
  node_ip=${etcd_node[$i]}

  if  [[ ! "${NODE_IPS[@]}" =~ "${node_ip}" ]] && [[ "${worker_node[@]}" =~ "${node_ip}" ]] ;then
    NODE_IPS[${#NODE_IPS[*]}]=${node_ip}
    NODE_NAMES[${#NODE_NAMES[*]}]=$(yq eval ".nodes[] | select(.address == \"${node_ip}\") | .hostname_override" ${cluster_yaml})
  fi
done
for ((i = 0; i < ${#worker_node[@]}; i++))
do
  node_ip=${worker_node[$i]}

  if  [[ ! "${NODE_IPS[@]}" =~ "${node_ip}" ]] ;then
    NODE_IPS[${#NODE_IPS[*]}]=${node_ip}
    NODE_NAMES[${#NODE_NAMES[*]}]=$(yq eval ".nodes[] | select(.address == \"${node_ip}\") | .hostname_override" ${cluster_yaml})
  fi
done

#处理 HOSTS
HOSTS_STR=""
for ((i = 0; i < ${#HOSTS[@]}; i++))
do
  HOST=${HOSTS[$i]}
  if [[ ! $i -eq 0 ]]; then
    HOSTS_STR="${HOSTS_STR}${HOST}\n"
  else
    HOSTS_STR="${HOST}\n"
  fi
done

APISERVER_IPS_STR=""
for ((i = 0; i < ${#controlplane_node[@]}; i++))
do
  APISERVER_NODE=${controlplane_node[$i]}
  if [[ ! $i -eq 0 ]]; then
    APISERVER_IPS_STR="${APISERVER_IPS_STR},\n\t\"${APISERVER_NODE}\""
  else
    APISERVER_IPS_STR="\"${APISERVER_NODE}\""
  fi
done

ETCD_NAMES=()
ETCD_IPS=()
ETCD_ENDPOINTS=()
ETCD_NODES=()
for ((i = 0; i < ${#etcd_node[@]}; i++))
do
  ETCD_NODE=${etcd_node[$i]}
  ETCD_NAME="etcd$(printf "%02d\n" $(expr $i + 1))"
  ETCD_NAMES[${#ETCD_NAMES[*]}]=${ETCD_NAME}
  ETCD_IPS[${#ETCD_IPS[*]}]="\"${ETCD_NODE}\""
  ETCD_ENDPOINTS[${#ETCD_ENDPOINTS[*]}]="https://${ETCD_NODE}:2379"
  ETCD_NODES[${#ETCD_NODES[*]}]="${ETCD_NAME}=https://${ETCD_NODE}:2380"
done

#处理 ETCD_IPS 、ETCD_ENDPOINTS 、ETCD_NODES
ETCD_IPS_STR=""
ETCD_ENDPOINTS_STR=""
ETCD_NODES_STR=""
for ((i = 0; i < ${#etcd_node[@]}; i++))
do
  ETCD_IP=${ETCD_IPS[$i]}
  ETCD_ENDPOINT=${ETCD_ENDPOINTS[$i]}
  ETCD_NODE=${ETCD_NODES[$i]}
  if [[ ! $i -eq 0 ]]; then
    ETCD_IPS_STR="${ETCD_IPS_STR},\n\t${ETCD_IP}"
    ETCD_ENDPOINTS_STR="${ETCD_ENDPOINTS_STR},${ETCD_ENDPOINT}"
    ETCD_NODES_STR="${ETCD_NODES_STR},${ETCD_NODE}"
  else
    ETCD_IPS_STR="${ETCD_IP}"
    ETCD_ENDPOINTS_STR="${ETCD_ENDPOINT}"
    ETCD_NODES_STR="${ETCD_NODE}"
  fi
done

# 原本产生的模板带有缩进，所以这里的加上了
APISERVER_IPS_STR=$(echo -e ${APISERVER_IPS_STR})
ETCD_IPS_STR=$(echo -e ${ETCD_IPS_STR})

cat > 00-environment.sh << EOF
#!/usr/bin/bash

# ssh端口号
export SSH_PORT=${ssh_port};

# 存放yaml文件的目录
export YAML_DIR=${base_yaml_dir}

# hosts 多个用\n隔开
export HOSTS='${HOSTS_STR}'

# 仅做生成token使用,在13-kubelet.sh使用
export WOKER_HOST_NAMES=(${WOKER_HOST_NAMES[@]})

# CA证书有效时间  10年
export CA_CERT_DATE="${base_ca_cert_date}"

# 统一证书有效时间 10年
export CERT_DATE="${base_cert_date}"

# 所有集群节点的ip数组  master节点放前面
export NODE_IPS=(${NODE_IPS[@]})

# master节点的ip数组
export MASTER_IPS=(${controlplane_node[@]})

# etcd节点的ip数组,仅在04-etcd.sh使用
export ETCD_CLUSTER_IPS=(${etcd_node[@]})

export ETCD_NAMES=(${ETCD_NAMES[@]})


# woker节点的ip数组  master节点放前面
export WOKER_IPS=(${worker_node[@]})

# woker节点的ip数组
export WOKER_NAMES=(${worker_node[@]})

# 集群各 IP 对应的hostname数组 按照先主后从的顺序写
export NODE_NAMES=(${NODE_NAMES[@]})

# apiserver集群服务地址ip
export APISERVER_IPS='${APISERVER_IPS_STR}'

# etcd 集群服务地址ip
export ETCD_IPS='${ETCD_IPS_STR}'

# etcd 集群服务地址列表 多个地址用,隔开
export ETCD_ENDPOINTS="${ETCD_ENDPOINTS_STR}"

# etcd 集群间通信的 IP 和端口 多个用,隔开
export ETCD_NODES="${ETCD_NODES_STR}"

# etcd 证书 目录
export ETCD_CERT_DIR="${service_etcd_cert_dir}"

# kube-apiserver 的反向代理(kube-nginx)地址端口
export KUBE_APISERVER="https://127.0.0.1:8443"

# 节点间互联网络接口名称
export IFACE="${service_flanneld_iface}"

# etcd 数据目录
export ETCD_DATA_DIR="${service_etcd_data_dir}"

# etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区
export ETCD_WAL_DIR="${service_etcd_wal_dir}"

# k8s 各组件数据 目录
export K8S_DIR="${service_k8s_dir}"

# k8s 工作 目录
export K8S_WORK_DIR="${service_k8s_work_dir}"

# k8s bin 目录
export K8S_BIN_DIR="${service_k8s_bin_dir}"

# k8s 数据父目录
export K8S_CERT_PARENT_DIR="${service_k8s_cert_parent_dir}"

# k8s 证书 目录
export K8S_CERT_DIR="${service_k8s_cert_dir}"

# docker 数据目录
export DOCKER_DIR="${service_docker_dir}"

# kube-nginx软件目录
export KUBE_NGINX_DIR="${service_kube_nginx_dir}"

# flanneld 证书 目录
export FLANNEL_CERT_DIR="${service_flanneld_cert_dir}"

# controller-manager集群服务地址ip
export CONTROLLER_MANAGER_IPS=\$APISERVER_IPS

# scheduler集群服务地址ip
export SCHEDULER_MANAGER_IPS=\$APISERVER_IPS

#### 以下参数一般不需要修改 ####

# 生成 EncryptionConfig 所需的加密 key
export ENCRYPTION_KEY=\$(head -c 32 /dev/urandom | base64)

# 最好使用 当前未用的网段 来定义服务网段和 Pod 网段

# 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证)
SERVICE_CIDR="${service_k8s_service_cidr}"

# Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证)
CLUSTER_CIDR="${service_k8s_cluster_cidr}"

# 服务端口范围 (NodePort Range)
export NODE_PORT_RANGE="${service_k8s_node_port_range}"

# flanneld 网络配置前缀
export FLANNEL_ETCD_PREFIX="${service_flanneld_etcd_prefix}"

# kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP)
export CLUSTER_KUBERNETES_SVC_IP="${service_k8s_cluster_kubernetes_svc_ip}"

# 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
export CLUSTER_DNS_SVC_IP="${service_k8s_cluster_dns_svc_ip}"

# 集群 DNS 域名（末尾不带点号）
export CLUSTER_DNS_DOMAIN="${service_k8s_cluster_dns_domain}"

# 将# k8s bin 目录 加到 PATH 中
export PATH=\$K8S_BIN_DIR:\$PATH
EOF

echo "生成 00-environment.sh 完成"

# 下载脚本文件
for i in ${RESOURCE_SHELL_URLS[@]} ;do download_resource "${i}" ; done
for i in ${SOFT_URLS[@]} ;do download_resource "${i}" ; done

chmod +x *.sh

echo "已经完成初始化"
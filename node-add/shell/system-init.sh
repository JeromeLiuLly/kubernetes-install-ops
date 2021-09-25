#!/bin/sh

####新的节点加入集群####
#获取当前执行脚本的目录
DIRNAME=$(cd "$(dirname "$0")";pwd)
source $DIRNAME/00-environment.sh

###1.系统基础优化
function optimize(){
	yum install -y epel-release
	yum install -y vim conntrack ntpdate ntp ipset jq iptables curl sysstat libseccomp wget unzip zip telnet sshpass expect lrzsz lsof openssh-clients*
}

###4.关闭防火墙
function stop_firewalld(){
	##停止firewalld服务
	systemctl stop firewalld
	##设置开机禁用防火墙
	systemctl disable firewalld

	systemctl stop iptables.service
	systemctl disable iptables

	##清除所有规则
	iptables -F && iptables -F -t nat
	##清除用户自定义规则
	iptables -X && iptables -X -t nat
	##刷新Forward跟accept规则
	iptables -P FORWARD ACCEPT
}

###5.关闭swap
function swap_off(){
	##禁用 /proc/swaps 中的所有交换区
	swapoff -a
	##注释掉/etc/fstab中所有 swap 的行
	sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
}

###6.关闭SELinux
function close_selinux(){
	##临时关闭
	setenforce 0
	##修改SELINUX=disabled 永久关闭
	sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	sed -i 's@SELINUX=enforcing@SELINUX=disabled@g' /etc/sysconfig/selinux
}

###7.加载内核模块
function load_core(){
	modprobe br_netfilter
}

###8.优化内核参数
function core_optimize(){
	##建一个文件夹用来存放k8s相关的文件
	mkdir -p $K8S_WORK_DIR
	cat > $K8S_WORK_DIR/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120

# 参考 https://github.com/prometheus/node_exporter#disabled-by-default
kernel.perf_event_paranoid=-1

#sysctls for k8s node config
net.ipv4.tcp_slow_start_after_idle=0
net.core.rmem_max=16777216
fs.inotify.max_user_watches=524288
kernel.softlockup_all_cpu_backtrace=1

kernel.softlockup_panic=0

kernel.watchdog_thresh=30
fs.file-max=2097152
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
vm.max_map_count=262144
fs.may_detach_mounts=1
net.core.netdev_max_backlog=16384
net.ipv4.tcp_wmem=4096 12582912 16777216
net.core.wmem_max=16777216
net.core.somaxconn=32768
net.ipv4.ip_forward=1
net.ipv4.tcp_max_syn_backlog=8096
net.ipv4.tcp_rmem=4096 12582912 16777216

net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

kernel.yama.ptrace_scope=0
vm.swappiness=0

# 可以控制core文件的文件名中是否添加pid作为扩展。
kernel.core_uses_pid=1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0

# Promote secondary addresses when the primary address is removed
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1

# Enable hard and soft link protection
fs.protected_hardlinks=1
fs.protected_symlinks=1

# 源路由验证
# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2

# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_synack_retries=2
kernel.sysrq=1
EOF

	##移动参数文件
	cp $K8S_WORK_DIR/kubernetes.conf  /etc/sysctl.d/kubernetes.conf
	##读取配置文件，使参数生效
	sysctl -p /etc/sysctl.d/kubernetes.conf
}

###9.设置系统时区
function set_date(){
	## 同步服务器时间
	systemctl enable ntpd
	systemctl restart ntpd
	##调整系统 TimeZone
	timedatectl set-timezone Asia/Shanghai
	##将当前的 UTC 时间写入硬件时钟
	timedatectl set-local-rtc 0
	##重启依赖于系统时间的服务
	systemctl restart rsyslog && systemctl restart crond
}

###10.关闭无关的服务
function colse_service(){
	systemctl stop postfix && systemctl disable postfix
}

###11.日志优化，这一步不需要了，如果做优化的话，会导致systemctl status 的日志查询变得很慢。

###12.创建相关目录
function mdkir_work(){
	mkdir -p  $K8S_WORK_DIR $K8S_BIN_DIR $K8S_CERT_DIR
}

###13.升级内核
function upgrade_core(){
	## 获取内核版本
	kernel_num=`uname -r`
	kernel_num=${kernel_num:0:1}
	## 如果内核版本为3.x版本,升级内核
	if [ "${kernel_num}" == 3 ]; then
		echo "升级内核版本,3.X版本升级为4.X"
	    ##安装完成后检查 /boot/grub2/grub.cfg 中对应内核 menuentry 中是否包含 initrd16 配置，如果没有，再安装一次！
	    #rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	    #rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
	    #yum --enablerepo=elrepo-kernel install -y kernel-lt
	    yum install -y ${K8S_WORK_DIR}/kernel-lt-5.4.104-1.el7.elrepo.x86_64.rpm
	    ##设置开机从新内核启动
	    grub2-set-default 0
	fi
}

###14.关闭 NUMA
function close_numa(){
	##在 GRUB_CMDLINE_LINUX 一行添加 `numa=off` 参数，如下所示：
	sed -i 's/GRUB_CMDLINE_LINUX=\"/&numa=off /' /etc/default/grub
	##重新生成 grub2 配置文件：
	cp /boot/grub2/grub.cfg{,.bak}
	grub2-mkconfig -o /boot/grub2/grub.cfg
}

###15.修改hosts文件
function update_hosts(){
	# 断言是否存在host映射
	num=`cat /etc/hosts | grep candao-k8s-hosts | wc -l`
	if [ ${num} == 0 ] ; then

	  cat >> /etc/hosts << EOF
###candao-k8s-hosts begin###
$(echo -e ${HOSTS})
###candao-k8s-hosts end###
EOF
	  ##因为HOSTS中参数是用'='号隔开的，应该替换成空格
	  sed -i 's/=/ /' /etc/hosts
	fi
}


###17.创建docker跟dev_dc账号
function create_user_docker(){
	useradd -m docker
	#useradd dev_dc
}

###18.更新 PATH 变量
function update_path(){
	echo "PATH=$PATH" >>/root/.bashrc
	source /root/.bashrc
}

###19.安装sshpass。这一步在yum那里装好了。

###20.清理文件夹
function clear_dir(){
    rm -rf $DOCKER_DIR/* $K8S_DIR/* $ETCD_DATA_DIR/* $ETCD_WAL_DIR/*
}


function main(){
	optimize
	stop_firewalld
	swap_off
	close_selinux
	load_core
	core_optimize
	set_date
	colse_service
	mdkir_work
	upgrade_core
	close_numa
	update_hosts
	create_user_docker
	update_path
	echo "init success！"
}

main "$@"

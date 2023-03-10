#!/bin/bash
#********************************************************************
#Author: Yuan Gao
#QQ： 915812780
#WeChat： youcai222
#Date： 2023年3月10日
#FileName： system_initialization-20230310-V7.0.sh
#URL： https://github.com/gaoyuan256/Script-library/tree/main
#Description： 20230310-V7.0
#********************************************************************

#临时调整中文字符集
#export LANG=zh_CN.ZHS16GBK
#export NLS_LANG='SIMPLIFIED CHINESE_CHINA'.ZHS16GBK
##export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK

#输出重定向
# 2>/dev/null
# 错误输出到“黑洞”
# 2>&1 >/dev/null
# 标准输出到“黑洞”，错误输出打印到屏幕
# >/dev/null 2>&1 (&> /dev/null)
# 标准输出和错误输出都进了“黑洞”

#颜色输出
gray(){
	echo -e "\033[30m\033[01m$1\033[0m\n"
}
reds(){
	echo -e "\033[31m\033[01m$1\033[0m\n"
}
green(){
	echo -e "\033[32m\033[01m$1\033[0m\n"
}
yellow(){
	echo -e "\033[33m\033[01m$1\033[0m\n"
}
blue(){
	echo -e "\033[34m\033[01m$1\033[0m\n"
}

#全局日期变量
cur_date=`date +%Y%m%d-%H%M%S`; export cur_date

#清屏
clear

#欢迎语句

gray '

                          _ooOoo_
                         o8888888o
                         88" . "88
                         (| -_- |)
                         O\  =  /O
                      ____/`---"\____
                    ."  \\|     |//  `.
                   /  \\|||  :  |||//  \
                  /  _||||| -:- |||||_  \
                  |   | \\\  -  /"| |   |
                  | \_|  `\`---"//  |_/ |
                  \  .-\__ `-. -"__/-.  /
                ___`. ."  /--.--\  `. ."___
             ."" "<  `.___\_<|>_/___." _> \"".
            | | :  `- \`. ;`. _/; ."/ /  ." ; |
            \  \ `-.   \_\_`. _."_/_/  -" _." /
================`-.`___`-.__\ \___  /__.-"_."_.-"================
                          `=--=-"                    

'

############################## 判断是否root用户 ##############################

if [[ `id | sed -r -n "s/uid=([0-9]{1,4}).*/\1/p"` != 0 ]]
then
	red '当前不是Root用户，不允许设置此优化,正在退出！'
	exit
fi

############################## 判断系统版本 ##############################

#Linux操作系统版本号
os_version=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`

#判断
if [ ! -n "$os_version" ]
then
	reds '版本检索失败，请手工确认！'
	exit
fi

#确认Linux系统版本，从而使用不同的系统命令
if [ -f "/etc/centos-release" ]
then
	green '当前操作系统版本为： CentOS-'$os_version''
else
	if [ -f "/etc/redhat-release" ]
	then
		green '当前操作系统版本为： RHEL-'$os_version''
	fi
fi

##############################1、关闭防火墙和Selinux##############################

close_firewalld_selinux() {

\cp -f /etc/selinux/config /etc/selinux/config.bak_$cur_date
setenforce 0 &> /dev/null
sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config

if grep 'SELINUX=disabled' /etc/selinux/config &> /dev/null
then
	echo -e '\e[1;32m1、SELinux 关闭成功！\e[0m\n'
else
	echo -e '\e[1;31m1、SELinux 关闭失败！\e[0m\n'
fi

echo -e '\e[1;32m1、查询确认\e[0m\e[1;33mDisabled\e[0m\e[1;32m为正常关闭！\e[0m\n'
echo -e "\e[1;32m1、SELinux 当前状态为： \e[0m\e[1;31m`getenforce`\e[0m\n"
echo -e '\e[1;32m1、请在重启后重新执行以下命令查询：\e[0m \e[1;33mgetenforce \e[0m\n'

if [[ $os_version == 7 ]]
then
	#清空iptables规则
	iptables -F;iptables -X
	service iptables save &> /dev/null
	systemctl disable iptables &> /dev/null
	systemctl disable libvirtd.service &> /dev/null

	#关闭防火墙
	systemctl stop firewalld &> /dev/null
	systemctl disable firewalld &> /dev/null

	#关闭NetworkManager
	systemctl stop NetworkManager &> /dev/null
	systemctl disable NetworkManager &> /dev/null
	echo -e '\e[1;32m1、请在重启后重新执行以下命令查询： \e[0m\n \e[1;33m
	systemctl status firewalld.service
	systemctl status NetworkManager.service
	iptables -L \e[0m\n'
elif [[ $os_version == 6 ]]
then
	#关闭iptables
	service iptables stop &> /dev/null
	chkconfig iptables off &> /dev/null

	#关闭NetworkManager
	service NetworkManager stop &> /dev/null
	chkconfig NetworkManager off &> /dev/null

	echo -e '\e[1;32m1、请在重启后重新执行以下命令查询： \e[0m\n \e[1;33m
	service firewalld status
	service NetworkManager status
	iptables -L \e[0m\n'
fi

}

##############################2、停止不必要系统服务##############################

stop_os_service() {

if [[ $os_version == 7 ]]
then
	for i in sendmail isdn pcmcia iptables mdmonitor smartd cups iiim httpd squid smb ip6tables gpm xend bluetooth NetworkManager\
		hidd pcscd iscsi iscsid avahi-daemon tog-pegasus yum-updatesd irqbalance mcstrans cpuspeed irqbalance bmc-watchdog cups-config-daemon
	do
		systemctl disable $i &> /dev/null
	done
	systemctl status NetworkManager | grep inactive &> /dev/null && echo -e '\e[1;32m2、停止不必要系统服务成功！\e[0m\n'

	#修改系统调优策略
	#设置优化概要文件变量为latency-performance（延迟性能：以增加功耗为代价优化确定性性能）
	tuned_profile='latency-performance'
	tuned-adm profile $tuned_profile &> /dev/null && echo -e '\e[1;32m2、修改系统调优策略为：\e[0m\e[1;33m' $tuned_profile '\e[0m\e[1;32m\e[0m\n'
	# tuned-adm list
	# tuned-adm active

elif [[ $os_version == 6 ]]
then
	#设置优化概要文件变量为latency-performance（延迟性能：以增加功耗为代价优化确定性性能）
	tuned_profile='latency-performance'

	for i in sendmail isdn pcmcia iptables mdmonitor rhnsd smartd cups cups-config-daemon iiim httpd squid smb ip6tables gpm xend bluetooth \
		hidd pcscd iscsi iscsid avahi-daemon tog-pegasus yum-updatesd irqbalance mcstrans NetworkManager postfix acpid cpuspeed
	do
		chkconfig $i off &> /dev/null
	done
	echo -e '\e[1;32m2、停止不必要系统服务成功！\e[0m\n'

	#设置优化概要文件变量为latency-performance（延迟性能：以增加功耗为代价优化确定性性能）
	tuned_profile='latency-performance'
	chkconfig rawdevices on &> /dev/null
	chkconfig tuned on &> /dev/null
	/etc/init.d/tuned start &> /dev/null
	tuned-adm profile $tuned_profile &> /dev/null && echo -e '\e[1;32m2、修改系统调优策略为：\e[0m\e[1;33m' $tuned_profile '\e[0m\e[1;32m\e[0m\n'
	# tuned-adm list
	# tuned-adm active
fi

}

##############################3、配置IP和BOND##############################

config_ip_bond() {

device_list=`cat /proc/net/dev | awk '{i++; if(i>2){print $1}}' | sed 's/^[\t]*//g' | sed 's/[:]*$//g'`

mkdir -p /etc/sysconfig/network-scripts/bak_$cur_date &> /dev/null
\cp -f /etc/sysconfig/network-scripts/ifcfg* /etc/sysconfig/network-scripts/bak_$cur_date &> /dev/null
\cp -f /etc/modprobe.d/dist.conf /etc/modprobe.d/dist.conf.bak_$cur_date &> /dev/null

read -p "3、请问您是否要配置网卡BOND（Yy/Nn）：" bondcon
echo ""

case $bondcon in
[Yy] )
echo -e '\e[1;32m3、请选择您要配置的网卡！\e[0m\n'
echo -e '\e[1;32m3、网卡设备列表为：\e[0m\n'
echo -e '\e[1;33m'$device_list'\e[0m\n'
read -p $'3、请输入您的网卡1：\n' device1
echo ""
read -p $'3、请输入您的网卡2：\n' device2
echo ""
read -p $'3、请输入您的BOND名称（如  bond0  ）\n' bond_name1
echo ""
read -p $'3、请输入您的 IP:    \n' ipadress1
echo ""
read -p $'3、请输入您的网关：\n' GATEWAY1
echo ""
read -p $'3、请输入您的子网掩码：\n' NETMASK1
echo ""
read -p $'3、请输入您的DNS：\n' DNS1
echo ""

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$bond_name1
DEVICE=$bond_name1
ONBOOT=yes
BOOTPROTO=static
IPADDR=$ipadress1
GATEWAY=$GATEWAY1
NETMASK=$NETMASK1
USERCTL=no
DNS1=$DNS1
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$device1
DEVICE=$device1
USERCTL=no
ONBOOT=yes
MASTER=$bond_name1
SLAVE=yes
BOOTPROTO=none
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$device2
DEVICE=$device2
USERCTL=no
ONBOOT=yes
MASTER=$bond_name1
SLAVE=yes
BOOTPROTO=none
EOF

cat <<EOF >> /etc/modprobe.d/dist.conf
alias $bond_name1 bonding
options $bond_name1 miimon=100 mode=1
#(说明：mode=0 为负载均衡， mode=1为冗余互备)
EOF

echo ""

echo -e '\e[1;32m3、Please manual execute:\e[0m \e[1;33m /etc/init.d/network restart \e[0m\n'
;;

[Nn] )
echo -e '\e[1;32m3、Please chose your network card!\e[0m\n'
echo -e '\e[1;32m3、网卡设备列表为：\e[0m\n'
echo -e '\e[1;33m'$device_list'\e[0m\n'
read -p $'3、请输入您的网卡：\n' device1
echo ""
read -p $'3、请输入您的 IP:    \n' ipadress1
echo ""
read -p $'3、请输入您的网关：\n' GATEWAY1
echo ""
read -p $'3、请输入您的子网掩码：\n' NETMASK1
echo ""
read -p $'3、请输入您的DNS：\n' DNS1
echo ""

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$device1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
NAME=$device1
DEVICE=$device1
ONBOOT=yes
IPADDR=$ipadress1
NETMASK=$NETMASK1
GATEWAY=$GATEWAY1
DNS1=$DNS1
EOF

echo -e '\e[1;32m3、请在确认后手动执行以下命令重启网卡：\e[0m\n'
echo -e '\e[1;33m3、/etc/init.d/network restart \e[0m\n'
;;

* )
echo -e '\e[1;31m3、请输入  Yy/Nn  ！\e[0m\n'
esac
}

##############################4、更改主机名和解析##############################

hosts_config() {

device_list=`cat /proc/net/dev | awk '{i++; if(i>2){print $1}}' | sed 's/^[\t]*//g' | sed 's/[:]*$//g'`
ipaddr_7=`ifconfig $device7 |awk -F '[ :]+' 'NR==2{print $3}'`
ipaddr_6=`ifconfig $device6 |awk -F '[ :]+' 'NR==2{print $4}'`

\cp -f /etc/hosts /etc/hosts.bak_$cur_date&> /dev/null

if [[ $os_version == 7 ]]
then
read -p $'4、请输入您要修改的主机名（推荐使用小写字母不超过8位）：  \n\n' hostname_7
hostnamectl set-hostname $hostname_7
echo ""
echo -e '\e[1;32m4、您的网卡设备列表为：\e[0m\n'
echo -e '\e[1;33m'$device_list'\e[0m\n'
read -p $'4、请输入您使用的网卡设备（如  eth0  ）：\n\n' device7
echo ""
if grep $ipaddr_7 /etc/hosts &> /dev/null
then
	sed -i "/$ipaddr_7/s/.*/$ipaddr_7    $hostname_7/" /etc/hosts
else
	echo "$ipaddr_7 $hostname_7" >> /etc/hosts
fi
if ping -c 2 -W 2 $hostname_7 &>/dev/null
then
	echo -e '\e[1;32m4、设置主机名解析成功！\e[0m\n'
else
	echo -e '\e[1;31m4、设置解析失败，请手动调整您的主机名解析！\e[0m\n'
fi
elif [[ $os_version == 6 ]]
then
echo -e '\e[1;31m4、请注意，Rhel及CentOS系统6.*版本，更改主机名后需重启后永久生效！\e[0m\n'
read -p $'4、请输入您要修改的主机名（推荐使用小写字母不超过8位）：  \n\n' hostname_6
sed -i "s/^HOSTNAME=.*/HOSTNAME=$hostname_6/" /etc/sysconfig/network
echo ""
echo -e '\e[1;32m4、您的网卡设备列表为：\e[0m\n'
echo -e '\e[1;33m'$device_list'\e[0m\n'
read -p $'4、请输入您使用的网卡设备（如  eth0  ）：\n\n' device6
echo ""
if grep $ipaddr_6 /etc/hosts &> /dev/null
then
	sed -i "/$ipaddr_6/s/.*/$ipaddr_6    $hostname_6/" /etc/hosts
else
	echo "$ipaddr_6 $hostname_6" >> /etc/hosts
fi
if ping -c 2 -W 2 $hostname_6 &>/dev/null
then
	echo -e '\e[1;32m4、设置主机名解析成功！\e[0m\n'
else
	echo -e '\e[1;31m4、设置解析失败，请手动调整您的主机名解析！\e[0m\n'
fi
fi

echo -e '\e[1;32m4、请确认/etc/hosts 解析情况：\n
\e[1;33mcat /etc/hosts\e[0m\n'

}

##############################5、配置YUM源##############################

yum_config() {

echo -e "选择您要使用的功能: \n"
echo -e " 1、我已上传ISO镜像到/software/iso/目录下，现在开始配置YUM源； \n 2. 我已上传ISO镜像到其他目录下，现在开始配置YUM源； \n 3. 尚未上传ISO镜像到/software/iso/目录下，仅配置YUM源； \n 0. 退出！ \n"
read -p $'输入数字以选择：\n\n' Function

if [ "$Function" == "1" ] || [ "$Function" == "2" ]; then
#echo -e '\e[1;33m5、请确认本地镜像是否上传或虚拟ISO是否添加！\e[0m\n'
echo ""
echo -e '\e[1;32m5、镜像挂载中……………………………………\e[0m\n'

mkdir -p /media/cdrom &> /dev/null
umount /media/cdrom &> /dev/null
umount /dev/sr0 &> /dev/null

if [[ $os_version == 7 ]]
then
	mount -o loop -t iso9660 /software/iso/rhel-server-7.*.iso /media/cdrom &> /dev/null
	mount -o loop -t iso9660 /software/iso/CentOS-7.*.iso /media/cdrom &> /dev/null
elif [[ $os_version == 6 ]]
then
	mount -o loop -t iso9660 /software/iso/rhel-server-6.*.iso /media/cdrom &> /dev/null
	mount -o loop -t iso9660 /software/iso/CentOS-6.*.iso /media/cdrom &> /dev/null
fi

mount /dev/sr0 /media/cdrom &> /dev/null
mount /dev/cdrom /media/cdrom &> /dev/null
mount /dev/hdc /media/cdrom &> /dev/null
mount /dev/scd0 /media/cdrom &> /dev/null

if df -h | grep cdrom &> /dev/null
then
	echo -e '\e[1;32m5、镜像挂载成功！\e[0m\n'
	mkdir -p /etc/yum.repos.d/bak_$cur_date    &> /dev/null
	\mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak_$cur_date &> /dev/null
	cat <<EOF > /etc/yum.repos.d/weizhi_dvd.repo
	[weizhi_dvd]
	name=weizhi_dvd
	baseurl=file:///media/cdrom
	enabled=1
	gpgcheck=0
EOF

	#yum 清除缓存
	yum clean all &> /dev/null
	yum makecache &> /dev/null
	echo -e "\e[1;32m5、Yum仓库信息如下：\e[0m\n"
	echo -e "\e[1;32m5、`yum repolist 2>/dev/null | grep "repolist"`\e[0m\n"
	yum install lrzsz -y &> /dev/null
else
	echo -e '\e[1;31m5、镜像挂载失败，请检查！\e[0m\n'
	echo -e '\e[1;31m5、请上传ISO镜像到/software/iso/目录下！\e[0m\n'
fi

if rpm -qa |grep lrzsz &> /dev/null
then
	echo -e '\e[1;32m5、Yum仓库配置成功！\e[0m\n'
else
	echo -e '\e[1;31m5、Yum仓库配置失败，请检查！\e[0m\n'
fi

elif [ "$Function" == "3" ]; then
mkdir -p /media/cdrom &> /dev/null
mkdir -p /software/iso &> /dev/null
mkdir -p /etc/yum.repos.d/bak_$cur_date    &> /dev/null
\mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak_$cur_date &> /dev/null
cat <<EOF > /etc/yum.repos.d/weizhi_dvd.repo
[weizhi_dvd]
name=weizhi_dvd
baseurl=file:///media/cdrom
enabled=1
gpgcheck=0
EOF
#yum 清除缓存
yum clean all &> /dev/null
else
exit 0
fi

}

##############################6、安装系统常用安装包##############################

install_packages() {

umount /media/cdrom              &> /dev/null
umount /dev/sr0                  &> /dev/null
mount  /dev/sr0   /media/cdrom   &> /dev/null
mount  /dev/cdrom /media/cdrom   &> /dev/null
mount  /dev/hdc   /media/cdrom   &> /dev/null
mount  /dev/scd0  /media/cdrom   &> /dev/null

yum clean all      &> /dev/null
yum makecache fast &> /dev/null

if [[ $os_version == 7 ]]
then
mount -o loop /software/iso/rhel-server-7.*.iso /media/cdrom &> /dev/null
mount -o loop /software/iso/CentOS-7.*.iso /media/cdrom &> /dev/null
#卸载系统强制初始化软件包，阻止每次重启GUI弹窗。
yum erase gnome-initial-setup -y &> /dev/null
echo -e '\e[1;35m6、软件包安装中，请等待 ……………………………………\e[0m\n'
elif [[ $os_version == 6 ]]
then
mount -o loop /software/iso/rhel-server-6.*.iso /media/cdrom &> /dev/null
mount -o loop /software/iso/CentOS-6.*.iso /media/cdrom &> /dev/null
echo -e '\e[1;35m6、软件包安装中，请等待 ……………………………………\e[0m\n'
fi

#for i in compat-libstdc++-33.i686 glibc.i686 glibc-devel.i686 \
#libgcc.i686 libstdc++.i686 libstdc++-devel.i686 \
#libaio.i686 libaio-devel.i686
for i in binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ \
glibc  glibc-devel ksh libgcc  libstdc++ \
libstdc++-devel  libaio  libaio-devel \
make sysstat libXp libXt libXtst zlib unixODBC \
unixODBC-devel lrzsz iotop elfutils-libelf-devel mlocate wget net-tools \
vim-enhanced hdparm tree pcre-devel telnet
do
yum install $i -y &>/dev/null
rpm -qa |grep $i &> /dev/null ||
echo -e '\e[1;31m6、（'$i'）软件包安装失败！\e[0m\n'
done

}

##############################7、配置NTP客户端##############################

config_ntp_client() {

read -p "7、请问您需要现在就开始配置时间同步服务么  (Yy/Nn):  " ntpcron
echo ""
ntp_bin=`which ntpdate`
hwclock_bin=`which hwclock`

case $ntpcron in
[Yy] )
read -p $'7、请输入您的时间同步服务端IP：\n' ntpserver1
crontab_ntp_job1="$ntp_bin  $ntpserver1 >> /tmp/ntpdate.log ; $hwclock_bin -w"
echo ""
if $ntp_bin  $ntpserver1 &> /tmp/ntpdate.log
then
$hwclock_bin -w &> /dev/null
mv /etc/localtime /etc/localtime.bak
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
tail -1 /tmp/ntpdate.log
echo ""
echo -e '\e[1;32m7、服务器当前时间为：\e[0m\n'
date
echo ""
crontab -l | grep -v "0 1 * * *  $crontab_ntp_job1"; echo "0 1 * * *  $crontab_ntp_job1" | crontab -
crontab -l
echo ""
echo -e '\e[1;32m7、时间同步服务配置成功！\e[0m\n'
else
echo ""
echo -e '\e[1;31m7、时间同步服务配置失败！\e[0m\n'
fi
;;
[Nn] )
echo -e '\e[1;32m7、欢迎您下次使用本工具配置时间同步服务！\e[0m\n'
#break
;;
* )
echo -e '\e[1;31m7、请输入字母 Y/y或N/n ！\e[0m\n'
esac
}

##############################8、SSH加速调整##############################

ssh_adjust(){

\cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_$cur_date
sed -i '/UseDNS/s/.*/UseDNS no/' /etc/ssh/sshd_config

if [[ $os_version == 7 ]]
then
systemctl restart sshd &> /dev/null
elif [[ $os_version == 6 ]]
then
/etc/init.d/sshd restart &> /dev/null
fi

if grep "UseDNS no" /etc/ssh/sshd_config &> /dev/null
then
green '8、SSH加速调整成功！'
else
reds '8、SSH加速调整失败，请检查！'
fi

}

##############################9、系统资源限制修改###########################

limits_config(){

\cp -f /etc/security/limits.conf  /etc/security/limits.conf.bak_$cur_date
cat >> /etc/security/limits.conf <<EOF
#grid             soft     nproc   65536
#grid             hard     nproc   65536
#grid             soft     nofile  65536
#grid             hard     nofile  65536
#grid             soft     stack   10240
#grid             hard     stack   65536
#grid           soft     memlock -1
#grid           hard     memlock -1
oracle           soft     nproc   65536
oracle           hard     nproc   65536
oracle           soft     nofile  65536
oracle           hard     nofile  65536
oracle           soft     stack   10240
oracle           hard     stack   65536
oracle           soft     memlock -1
oracle           hard     memlock -1
EOF

grep 'oracle           soft     memlock -1' /etc/security/limits.conf &> /dev/null \
&& green '9、系统资源限制修改成功！' \
|| reds '9、系统资源限制修改失败！'

}

##############################10、系统内核参数##############################

sysctl_config(){

\cp -f /etc/sysctl.conf /etc/sysctl.conf.bak_$cur_date
cat >> /etc/sysctl.conf <<EOF
kernel.core_uses_pid = 1
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.core.rmem_default = 262144
net.core.wmem_default = 262144
fs.aio-max-nr = 3145728
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.vfs_cache_pressure = 200
vm.min_free_kbytes = 409600
vm.nr_hugepages = 1
EOF

sysctl -p &> /dev/null
grep 'kernel.shmmax = 4398046511104' /etc/sysctl.conf &> /dev/null \
&& green '10、系统内核参数配置成功！' \
|| reds '10、系统内核参数配置失败！'

}

##############################11、系统全局环境变量##############################

all_profile_config(){

\cp -f /etc/profile /etc/profile.bak_$cur_date

cat >> /etc/profile <<EOF
if [ \$USER = "oracle" ]; then
	if [ \$SHELL = "/bin/ksh" ]; then
		ulimit -p 16384
		ulimit -n 65536
	else
		ulimit -u 16384 -n 65536
	fi
fi

TMOUT=300

USER_IP=\`who -u am i | awk '{print \$NF}'|sed -e 's/[()]//g'\`
if [ -z \$USER_IP  ]
then
	USER_IP="NO_client_IP"
fi
export HISTSIZE=4096
export HISTTIMEFORMAT="[%Y.%m.%d %H:%M:%S]~{\$USER_IP}~[\$USER]  "

EOF

source /etc/profile
grep '$USER = "oracle' /etc/profile &> /dev/null \
&& green '11、系统全局环境变量配置成功！' \
|| reds '11、系统全局环境变量配置失败！'
}

##############################12、透明大页关闭##############################

transparent_hugepage_config() {

echo never > /sys/kernel/mm/transparent_hugepage/enabled \
&& cat /sys/kernel/mm/transparent_hugepage/enabled | grep "\[never\]" &> /dev/null \
&& echo -e '\e[1;32m12、透明大页关闭成功，请在重启后重新确认！[enabled]\e[0m\n' \
|| echo -e '\e[1;31m12、透明大页关闭失败，请检查！\e[0m\n'

echo never > /sys/kernel/mm/transparent_hugepage/defrag \
&& cat /sys/kernel/mm/transparent_hugepage/defrag | grep "\[never\]" &> /dev/null \
&& echo -e '\e[1;32m12、透明大页关闭成功，请在重启后重新确认！[defrag]\e[0m\n' \
|| echo -e '\e[1;31m12、透明大页关闭失败，请检查！\e[0m\n'

\cp -f /etc/rc.d/rc.local /etc/rc.d/rc.local.bak_$cur_date &> /dev/null
\cp -f /etc/grub.conf /etc/grub.conf_$cur_date &> /dev/null

#sed -i 's/quiet/quiet numa=off/' /etc/grub.conf &> /dev/null
sed -i 's/quiet/quiet numa=off/' /boot/grub/grub.conf &> /dev/null
cat <<EOF >> /etc/rc.d/rc.local
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
	echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
chmod +x /etc/rc.d/rc.local

if [[ $os_version == 7 ]]
then
	\cp -f /etc/default/grub /etc/default/grub.bak_$cur_date &> /dev/null
	\cp -f /boot/grub2/grub.cfg /boot/grub2/grub.cfg.bak_$cur_date &> /dev/null
	\cp -f /boot/efi/EFI/redhat/grub.cfg /boot/efi/EFI/redhat/grub.cfg.bak_$cur_date &> /dev/null

	#echo 'GRUB_CMDLINE_LINUX="transparent_hugepage=never numa=off"' >>/etc/default/grub
	sed -i 's/quiet/quiet transparent_hugepage=never numa=off/' /etc/default/grub
	grub2-mkconfig -o /boot/grub2/grub.cfg &> /dev/null
	grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg &> /dev/null
fi

yellow '12、请在重启后重新执行以下命令查询：'
yellow '12、cat /sys/kernel/mm/transparent_hugepage/enabled | grep "\[never\]"'
yellow '12、cat /sys/kernel/mm/transparent_hugepage/defrag | grep "\[never\]"'
yellow '12、grep Huge /proc/meminfo'
yellow '12、请确认AnonHugePages为0正常！'
yellow '12、dmesg | grep -i  "numa turned off"'
yellow '12、cat /proc/cmdline | grep -i "numa=off"'
yellow '12、numactl --hardware | grep -i nodes'
yellow '12、请确认available为2或多个nodes就说明numa没关掉！'

}

##############################13、磁盘调度算法##############################

scheduler_config() {
echo -e '\e[1;32m13、存储设备列表为：\e[0m'
lsblk
echo ""
read -p "13、请输入您想选择的存储设备（如sda或sdb）： " device_scheduler
echo ""

echo -e '\e[1;32m13、调度算法列表为：\e[0m'
if [[ $os_version == 7 ]]
then
	dmesg | grep -i scheduler | cut -d" " -f 8
elif [[ $os_version == 6 ]]
then
	dmesg | grep -i scheduler | cut -d" " -f 3
fi
echo ""
read -p "13、请输入您想选择的调度算法（如noop）： " scheduler_name
echo ""

echo $scheduler_name > /sys/block/$device_scheduler/queue/scheduler \
&& echo -e '\e[1;32m13、'$scheduler_name'调度算法设置成功！\e[0m\n' \
|| echo -e '\e[1;31m13、'$scheduler_name'调度算法设置失败！\e[0m\n'

if [[ $os_version == 7 ]]
then
	grubby --update-kernel=ALL --args="elevator=$scheduler_name"
elif [[ $os_version == 6 ]]
then
	\cp -f /boot/grub/menu.lst /boot/grub/menu.lst.bak_$cur_date
	\cp -f /boot/grub/menu.lst /boot/grub/grub.conf.bak_$cur_date
	sed -i 's/quiet/quiet elevator='$scheduler_name'/' /boot/grub/menu.lst
	sed -i 's/quiet/quiet elevator='$scheduler_name'/' /boot/grub/grub.conf
fi

echo -e '\e[1;32m13、请在重启后重新执行以下命令查询：\e[0m\n'
echo -e '\e[1;33m13、cat /sys/block/'$device_scheduler'/queue/scheduler |grep '\[$scheduler_name\]'\e[0m\n'

}

##############################14、ORACLE用户设置##############################
#ORACLE用户及组
oracle_create_user="oracle"
oracle_create_user_passwd="oracle"
oracle_create_group54321="oinstall"
oracle_create_group54322="dba"
oracle_create_group54323="oper"

oracle_user_config() {
#创建oinstall组
cat /etc/group | cut -f1 -d':' | grep "$oracle_create_group54321" >/dev/null 2>&1
if [ $? -ne 0 ]
then
	groupadd -g 54321 $oracle_create_group54321 &> /dev/null
else
	echo -e '\e[1;31m14、用户组 '$oracle_create_group54321' 已存在！\e[0m\n'
fi

#创建dba组
cat /etc/group | cut -f1 -d':' | grep "$oracle_create_group54322" >/dev/null 2>&1
if [ $? -ne 0 ]
then
	groupadd -g 54322 $oracle_create_group54322 &> /dev/null
else
	echo -e '\e[1;31m14、用户组 '$oracle_create_group54322' 已存在！\e[0m\n'
fi

#创建oper组
cat /etc/group | cut -f1 -d':' | grep "$oracle_create_group54323" >/dev/null 2>&1
if [ $? -ne 0 ]
then
	groupadd -g 54323 $oracle_create_group54323 &> /dev/null
else
	echo -e '\e[1;31m14、用户组 '$oracle_create_group54323' 已存在！\e[0m\n'
fi

#创建oracle用户
cat /etc/passwd | cut -f1 -d':' | grep "$oracle_create_user" >/dev/null 2>&1
if [ $? -ne 0 ]
then
	useradd  -u 54321 -g $oracle_create_group54321 -G $oracle_create_group54322,$oracle_create_group54323 -d /home/oracle -s /bin/bash oracle &> /dev/null
	echo ''$oracle_create_user_passwd'' | passwd --stdin oracle &> /dev/null
	id oracle | grep 'uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),54322(dba),54323(oper)'  &> /dev/null \
	&& echo -e '\e[1;32m14、用户'$oracle_create_user' 创建成功！\e[0m\n' \
	&& echo -e '\e[1;32m14、用户'$oracle_create_user'信息如下\e[0m\n' \
	&& echo -e '\e[1;32m14、'`id oracle`'\e[0m\n' \
	&& echo -e '\e[1;32m14、用户 '$oracle_create_user' 密码如下\e[0m\n' \
	&& echo -e '\e[1;30m14、'$oracle_create_user_passwd'\e[0m\n'
else
	echo -e '\e[1;31m14、用户 '$oracle_create_user' 已存在！\e[0m\n'
	echo -e '\e[1;32m14、用户 '$oracle_create_user' 信息如下\e[0m\n'
	echo -e '\e[1;32m14、'`id oracle`'\e[0m\n'
fi
}

##############################15、ORACLE目录设置##############################
ora_home_11g="/u01/app/oracle/product/11G_R2/db"
ora_home_12c="/u01/app/oracle/product/12C/db"
ora_home_18c="/u01/app/oracle/product/18C/db"
ora_home_19c="/u01/app/oracle/product/19C/db"

oracle_dir_config() {
ORACLEDIR=$(whiptail --title "Oracle-version-selection" --radiolist \
"Choose preferred Linux distros" 25 60 5 \
"1" "Install 11G $ora_home_11g" OFF \
"2" "Install 12C $ora_home_12c" OFF \
"3" "Install 18C $ora_home_18c" OFF \
"4" "Install 19C $ora_home_19c" OFF \
"5" "EXIT" OFF 3>&1 1>&2 2>&3)

exitstatus=$?

for l in $ORACLEDIR
do
	case $l in
	'1')
	#创建ORACLE_HOME目录
	ora_base='/u01/app/oracle'
	ora_home=$ora_home_11g
	ora_directory="/u01"
	if [ ! -d "$ora_home" ]
	then
		mkdir -p $ora_home
		chown -R oracle:oinstall $ora_directory &> /dev/null && ls -lh  $ora_directory &> /dev/null \
		&& echo -e '\e[1;32m15、ORACLE_HOME目录 '$ora_home' 创建成功！\e[0m\n' \
		|| echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 创建失败！\e[0m\n'
		echo ""
	else
		echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 已存在！\e[0m\n'
	fi
;;

'2')
#创建ORACLE_HOME目录
ora_base='/u01/app/oracle'
ora_home=$ora_home_12c
ora_directory="/u01"
if [ ! -d "$ora_home" ]
then
	mkdir -p $ora_home
	chown -R oracle:oinstall $ora_directory &> /dev/null && ls -lh  $ora_directory &> /dev/null \
	&& echo -e '\e[1;32m15、ORACLE_HOME目录 '$ora_home' 创建成功！\e[0m\n' \
	|| echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 创建失败！\e[0m\n'
else
	echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 已存在！\e[0m\n'
fi
;;

'3')
#创建ORACLE_HOME目录
ora_base='/u01/app/oracle'
ora_home=$ora_home_18c
ora_directory="/u01"
if [ ! -d "$ora_home" ]
then
mkdir -p $ora_home
chown -R oracle:oinstall $ora_directory &> /dev/null && ls -lh  $ora_directory &> /dev/null \
&& echo -e '\e[1;32m15、ORACLE_HOME目录 '$ora_home' 创建成功！\e[0m\n' \
|| echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 创建失败！\e[0m\n'
else
echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 已存在！\e[0m\n'
fi
;;

'4')
#创建ORACLE_HOME目录
ora_base='/u01/app/oracle'
ora_home=$ora_home_19c
ora_directory="/u01"
if [ ! -d "$ora_home" ]
then
mkdir -p $ora_home
chown -R oracle:oinstall $ora_directory &> /dev/null && ls -lh  $ora_directory &> /dev/null \
&& echo -e '\e[1;32m15、ORACLE_HOME目录 '$ora_home' 创建成功！\e[0m\n' \
|| echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 创建失败！\e[0m\n'
else
echo -e '\e[1;31m15、ORACLE_HOME目录 '$ora_home' 已存在！\e[0m\n'
fi
;;

'5')
exit
;;

* )
esac
done


#创建SOFTWARE目录
read -p "15、请输入软件包存放目录：（如  /software  ）： " software_directory
if [ ! -d "$software_directory" ]
then
mkdir -p $software_directory
echo ""
chown -R oracle:oinstall $software_directory &> /dev/null && ls -lh $software_directory &> /dev/null \
&& echo -e '\e[1;32m15、软件包存放目录 '$software_directory' 创建成功！\e[0m\n' \
|| echo -e '\e[1;31m15、软件包存放目录 '$software_directory' 创建失败！\e[0m\n'
else
echo ""
echo -e '\e[1;31m15、软件包存放目录  '$software_directory' 已存在！\e[0m\n'
fi

#创建ORACLE数据文件目录
read -p "15、请输入ORACLE数据文件目录：（如  /oradata  ）： " data_directory
if [ ! -d "$data_directory" ]
then
mkdir -p $data_directory
echo ""
chown -R oracle:oinstall $data_directory &> /dev/null && ls -lh  $data_directory &> /dev/null \
&& echo -e '\e[1;32m15、ORACLE数据文件目录 '$data_directory' 创建成功！\e[0m\n' \
|| echo -e '\e[1;31m15、ORACLE数据文件目录 '$data_directory' 创建失败！\e[0m\n'
else
echo ""
echo -e '\e[1;31m15、ORACLE数据文件目录  '$data_directory' 已存在！\e[0m\n'
fi

#创建ORACLE归档文件目录
read -p "15、请输入ORACLE归档文件目录：（如  /oradata/arch  ）： " arch_directory
if [ ! -d "$arch_directory" ]
then
mkdir -p $arch_directory
echo ""
chown -R oracle:oinstall $arch_directory &> /dev/null && ls -lh $arch_directory &> /dev/null \
&& echo -e '\e[1;32m15、ORACLE归档文件目录 '$arch_directory' 创建成功！\e[0m\n' \
|| echo -e '\e[1;31m15、ORACLE归档文件目录 '$arch_directory' 创建失败！\e[0m\n'
else
echo ""
echo -e '\e[1;31m15、ORACLE归档文件目录 '$arch_directory' 已存在！\e[0m\n'
fi
}


##############################16、ORACLE环境变量修改############################
oracle_profile_config() {
echo -e '\e[1;32m16、请选择您要安装的Oracle版本： \e[0m\n'
echo ""
echo -e '\e[1;33m16、11G目录请输入： '$ora_home_11g' \e[0m'
echo -e '\e[1;33m16、12C目录请输入： '$ora_home_12c' \e[0m'
echo -e '\e[1;33m16、18C目录请输入： '$ora_home_18c' \e[0m'
echo -e '\e[1;33m16、19C目录请输入： '$ora_home_19c' \e[0m\n'

#    read -p "Please enter your ORACLE_BASE:(/u01/app/oracle)  " ora_base2
ora_base2='/u01/app/oracle'
read -p "请输入您的ORACLE_HOME（如  /u01/app/oracle/product/11G_R2/db  ）：" ora_home2
read -p "请输入您的ORACLE_SID（如  orcl  ）：" ora_sid2

\cp -f /home/oracle/.bash_profile /home/oracle/.bash_profile.bak_$cur_date &> /dev/null
echo ""

cat >> /home/oracle/.bash_profile <<EOF

export ORACLE_BASE=$ora_base2
export ORACLE_HOME=$ora_home2
export ORACLE_SID=$ora_sid2
export ORACLE_TERM=xterm
export ORACLE_OWNER=oracle
export NLS_DATE_FORMATE="YYYY-MM-DD HH24:MI:SS"
export TMP=/tmp
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export ORA_NLS33=\$ORACLE_HOME/ocommon/nls/admin/data
#export NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK" --AL32UTF8 select userenv('LANGUAGE') db_NLS_LANG from dual;
export NLS_LANG="AMERICAN_CHINA.ZHS16GBK"
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$ORACLE_HOME/network/lib:/lib:/usr/lib:/usr/local/lib
export LIBPATH=\$ORACLE_HOME/lib:\$ORACLE_HOME/network/lib:/lib:/usr/lib:/usr/local/lib
export PATH=\$PATH:/sbin:/usr/lbin:/usr/sbin:\$JAVA_HOME/bin:\$ORACLE_HOME/bin:\$ORACLE_HOME/lib:\$HOME/bin:\$ORACLE_HOME/OPatch:.
stty erase ^H
umask 022
EOF

source /home/oracle/.bash_profile

echo -e '\e[1;32m16、Oracle用户环境变量如下： \e[0m\n'
env | grep 'ORACLE_OWNER'
env | grep 'ORACLE_BASE'
env | grep 'ORACLE_HOME'
env | grep 'ORACLE_SID'
echo ""
env | grep $ora_home2 &> /dev/null && echo -e '\e[1;32m16、Oracle用户环境变量配置成功！\e[0m\n'

}


##############################17、收集系统信息#################################
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
source /etc/profile

[ $(id -u) -gt 0 ] && echo "请用root用户执行此脚本！" && exit 1

centosVersion=$(awk '{print $(NF-1)}' /etc/redhat-release)
VERSION=`date +%F`

#日志相关
ipp=`ifconfig |grep inet|egrep -v '192.168.10.164|127.0.0.1|inet6'| awk '{print$2}'`
#RESULTFILE="/tmp/`ifconfig |grep inet|egrep -v '192.168.10.164|127.0.0.1|inet6'| awk '{print$2}'`.txt"
RESULTFILE="/tmp/`hostname`-`date +"%Y-%m-%d_%H-%M-%S"`.txt"

function version(){
echo "################################################################################################################"
echo "################################################################################################################"
echo "系统巡检：DATE:  $VERSION"
}

function getSystemStatus() {
echo ""
echo -e "###系统检查"
if [ -e /etc/sysconfig/i18n ]
then
default_LANG="$(grep "LANG=" /etc/sysconfig/i18n | grep -v "^#" | awk -F '"' '{print $2}')"
else
default_LANG=$LANG
fi
export LANG="en_US.UTF-8"
Release=$(cat /etc/redhat-release 2>/dev/null)
Kernel=$(uname -r)
OS=$(uname -o)
Hostname=$(uname -n)
SELinux=$(/usr/sbin/sestatus | grep "SELinux status: " | awk '{print $3}')
LastReboot=$(who -b | awk '{print $3,$4}')
uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
echo "     系统：$OS"
echo " 发行版本：$Release"
echo "     内核：$Kernel"
echo "   主机名：$Hostname"
echo "  SELinux：$SELinux"
echo "语言/编码：$default_LANG"
echo " 当前时间：$(date +'%F %T')"
echo " 最后启动：$LastReboot"
echo " 运行时间：$uptime"
echo "   uptime: `uptime`"
echo " runlevel: `runlevel`"
}

function getCpuStatus(){
echo ""
echo -e "###CPU检查"
Physical_CPUs=$(grep "physical id" /proc/cpuinfo| sort | uniq | wc -l)
Virt_CPUs=$(grep "processor" /proc/cpuinfo | wc -l)
CPU_Kernels=$(grep "cores" /proc/cpuinfo|uniq| awk -F ': ' '{print $2}')
CPU_Type=$(grep "model name" /proc/cpuinfo | awk -F ': ' '{print $2}' | sort | uniq)
CPU_Arch=$(uname -m)
echo "物理CPU个数:$Physical_CPUs"
echo "逻辑CPU个数:$Virt_CPUs"
echo "每CPU核心数:$CPU_Kernels"
echo "    CPU型号:$CPU_Type"
echo "    CPU架构:$CPU_Arch"
}

function getMemStatus(){
echo ""
echo  -e "###内存检查"
if [[ $centosVersion < 7 ]]
then
free -mo
else
free -h
fi
}

function getDiskStatus() {
echo ""
echo -e "###磁盘检查"
df -hiP | sed 's/Mounted on/Mounted/'> /tmp/inode
df -hTP | sed 's/Mounted on/Mounted/'> /tmp/disk
join /tmp/disk /tmp/inode | awk '{print $1,$2,"|",$3,$4,$5,$6,"|",$8,$9,$10,$11,"|",$12}'| column -t|tee /tmp/join
echo ""
echo -e "$(for i in `cat /tmp/join|grep %|awk '{print$7,$12}'|grep -v '[a-zA-Z]'|column -t|tr -d %`;do if [ $i -gt 80 ] 2>/dev/null;then echo '注意有磁盘空间占用大于80%' ;fi;done)"
}

function getNetworkStatus(){
echo ""
echo -e "###网络检查"
if [[ $centosVersion < 7 ]]
then
/sbin/ifconfig -a | grep -v packets | grep -v collisions | grep -v inet6
else
for i in $(ip link | grep BROADCAST | awk -F: '{print $2}');do ip add show $i | grep -E "BROADCAST|global"| awk '{print $2}' | tr '\n' ' ' ;echo "" ;done
fi
GATEWAY=$(ip route | grep default | awk '{print $3}')
DNS=$(grep nameserver /etc/resolv.conf| grep -v "#" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
echo ""
echo "网关：$GATEWAY "
echo "DNS：$DNS"
echo ""
ping -c 4 $GATEWAY >/dev/null 2>&1
if [ $? -eq 0 ]
then
echo "网络连接：正常"
else
echo "网络连接：异常"
fi
}

function getListenStatus(){
echo ""
echo  -e "###监听检查"
TCPListen=$(ss -s | column -t)
echo "$TCPListen"
}

function getProcessStatus(){
echo ""
echo -e "###进程检查"
if [ $(ps -ef | grep defunct | grep -v grep | wc -l) -ge 1 ]
then
echo ""
echo "僵尸进程";
echo "--------"
ps -ef | head -n1
ps -ef | grep defunct | grep -v grep
fi
echo ""
echo -e "###内存占用TOP10"
echo "-------------"
echo -e "###PID %MEM RSS COMMAND
$(ps aux | awk '{print $2, $4, $6, $11}' | sort -k3rn | head -n 10 )"| column -t
echo ""
echo -e "###CPU占用TOP10"
echo "------------"
top b -n1 | head -17 | tail -11

}

function getServiceStatus(){
echo ""
echo -e "###服务检查"
echo ""
if [[ $centosVersion > 7 ]]
then
conf=$(systemctl list-unit-files --type=service --state=enabled --no-pager | grep "enabled")
process=$(systemctl list-units --type=service --state=running --no-pager | grep ".service")
else
conf=$(/sbin/chkconfig | grep -E ":on|:启用")
process=$(/sbin/service --status-all 2>/dev/null | grep -E "is running|正在运行")
fi
echo "服务配置"
echo "--------"
echo "$conf"  | column -t
echo ""
#    echo "正在运行的服务"
#    echo "--------------"
#    echo "$process"
}

function getulimitStatus(){
echo ""
echo -e "###文件打开数检查"
ulimit -a
}


function getAutoStartStatus(){
echo ""
echo -e "###自启动检查"
conf=$(grep -v "^#" /etc/rc.d/rc.local| sed '/^$/d')
echo "$conf"
}


function getLoginStatus(){
echo ""
echo -e "###登录检查"
last | head
}



function getCronStatus(){
echo ""
echo -e "###计划任务检查"
Crontab=0
for shell in $(grep -v "/sbin/nologin" /etc/shells);do
for user in $(grep "$shell" /etc/passwd| awk -F: '{print $1}');do
crontab -l -u $user >/dev/null 2>&1
status=$?
if [ $status -eq 0 ]
then
echo "$user"
echo "--------"
crontab -l -u $user
let Crontab=Crontab+$(crontab -l -u $user | wc -l)
echo ""
fi
done
done
#计划任务
find /etc/cron* -type f | xargs -i ls -l {} | column  -t
echo ""
crontab -l -u root 2>/dev/null
crontab -l -u oracle 2>/dev/null
}

function getUserStatus(){
echo ""
echo -e "###用户检查"
#/etc/passwd 最后修改时间
pwdfile="$(cat /etc/passwd)"
Modify=$(stat /etc/passwd | grep Modify | tr '.' ' ' | awk '{print $2,$3}')

echo "/etc/passwd: $Modify ($(getHowLongAgo $Modify))"
echo ""
echo "特权用户"
echo "--------"
RootUser=""
for user in $(echo "$pwdfile" | awk -F: '{print $1}');do
if [ $(id -u $user) -eq 0 ]
then
echo "$user"
RootUser="$RootUser,$user"
fi
done
echo ""
echo "用户列表"
echo "--------"
USERs=0
echo "$(
echo "用户名 UID GID HOME SHELL 最后一次登录"
for shell in $(grep -v "/sbin/nologin" /etc/shells);do
for username in $(grep "$shell" /etc/passwd| awk -F: '{print $1}');do
userLastLogin="$(getUserLastLogin $username)"
echo "$pwdfile" | grep -w "$username" |grep -w "$shell"| awk -F: -v lastlogin="$(echo "$userLastLogin" | tr ' ' '_')" '{print $1,$3,$4,$6,$7,lastlogin}'
done
let USERs=USERs+$(echo "$pwdfile" | grep "$shell"| wc -l)
done
)" | column -t
echo ""
echo "空密码用户"
echo "----------"
USEREmptyPassword=""
for shell in $(grep -v "/sbin/nologin" /etc/shells);do
for user in $(echo "$pwdfile" | grep "$shell" | cut -d: -f1);do
r=$(awk -F: '$2=="!!"{print $1}' /etc/shadow | grep -w $user)
if [ ! -z $r ]
then
echo $r
USEREmptyPassword="$USEREmptyPassword,"$r
fi
done
done
echo ""
echo "相同ID的用户"
echo "------------"
USERTheSameUID=""
UIDs=$(cut -d: -f3 /etc/passwd | sort | uniq -c | awk '$1>1{print $2}')
for uid in $UIDs;do
echo -n "$uid";
USERTheSameUID="$uid"
r=$(awk -F: 'ORS="";$3=='"$uid"'{print ":",$1}' /etc/passwd)
echo "$r"
echo ""
USERTheSameUID="$USERTheSameUID $r,"
done

}

function getPasswordStatus {
echo ""
echo -e "###密码检查"
pwdfile="$(cat /etc/passwd)"
echo ""
echo "密码过期检查"
echo "------------"
result=""
for shell in $(grep -v "/sbin/nologin" /etc/shells);do
for user in $(echo "$pwdfile" | grep "$shell" | cut -d: -f1);do
get_expiry_date=$(/usr/bin/chage -l $user | grep 'Password expires' | cut -d: -f2)
if [[ $get_expiry_date = ' never' || $get_expiry_date = 'never' ]]
then
printf "%-15s 永不过期\n" $user
result="$result,$user:never"
else
password_expiry_date=$(date -d "$get_expiry_date" "+%s")
current_date=$(date "+%s")
diff=$(($password_expiry_date-$current_date))
let DAYS=$(($diff/(60*60*24)))
printf "%-15s %s天后过期\n" $user $DAYS
result="$result,$user:$DAYS days"
fi
done
done
report_PasswordExpiry=$(echo $result | sed 's/^,//')

echo ""
echo "密码策略检查"
echo "------------"
grep -v "#" /etc/login.defs | grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE"
cat /etc/pam.d/system-auth
}


function getSudoersStatus(){
echo ""
echo -e "###Sudoers检查"
conf=$(grep -v "^#" /etc/sudoers| grep -v "^Defaults" | sed '/^$/d')
echo "$conf"
echo ""
}

function getJDKStatus(){
echo ""
echo -e "###JDK检查"
java -version 2>/dev/null
if [ $? -eq 0 ]
then
java -version 2>&1
fi
echo "JAVA_HOME=\"$JAVA_HOME\""
}

function getFirewallStatus(){
echo ""
echo -e "###防火墙检查"
#防火墙状态，策略等
if [[ $centosVersion = 7 ]]
then
systemctl status firewalld >/dev/null  2>&1
status=$?
if [ $status -eq 0 ]
then
s="active"
elif [ $status -eq 3 ]
then
s="inactive"
elif [ $status -eq 4 ]
then
s="permission denied"
else
s="unknown"
fi
else
s="$(getState iptables)"
fi
echo "firewalld: $s"
echo ""
echo "/etc/sysconfig/firewalld"
echo "-----------------------"
cat /etc/sysconfig/firewalld 2>/dev/null
}

function getSSHStatus(){
#SSHD服务状态，配置,受信任主机等
echo ""
echo -e "###SSH检查"
#检查受信任主机
pwdfile="$(cat /etc/passwd)"
echo "服务状态：$(getState sshd)"
#Protocol_Version=$(cat /etc/ssh/sshd_config | grep Protocol | awk '{print $2}')
Protocol_Version=`ssh -V` &> /dev/null
echo "SSH协议版本：$Protocol_Version"
echo ""
echo "信任主机"
echo "--------"
authorized=0
for user in $(echo "$pwdfile" | grep /bin/bash | awk -F: '{print $1}');do
authorize_file=$(echo "$pwdfile" | grep -w $user | awk -F: '{printf $6"/.ssh/authorized_keys"}')
authorized_host=$(cat $authorize_file 2>/dev/null | awk '{print $3}' | tr '\n' ',' | sed 's/,$//')
if [ ! -z $authorized_host ]
then
echo "$user 授权 \"$authorized_host\" 无密码访问"
fi
let authorized=authorized+$(cat $authorize_file 2>/dev/null | awk '{print $3}'|wc -l)
done

echo ""
echo "是否允许ROOT远程登录"
echo "--------------------"
config=$(cat /etc/ssh/sshd_config | grep PermitRootLogin)
firstChar=${config:0:1}
if [ $firstChar == "#" ]
then
PermitRootLogin="yes"
else
PermitRootLogin=$(echo $config | awk '{print $2}')
fi
echo "PermitRootLogin $PermitRootLogin"

echo ""
echo "/etc/ssh/sshd_config"
echo "--------------------"
cat /etc/ssh/sshd_config | grep -v "^#" | sed '/^$/d'
}

function getotherStatus(){
echo ""
echo -e "###var/log/messages-error检查"
grep -i error /var/log/messages
echo ""
echo -e "###dmesg-fail/error检查"
dmesg |grep fail
dmesg |grep error
}


function getInstalledStatus(){
echo ""
echo -e "###软件检查"
#   rpm -qa --last | head | column -t
rpm -qa --last|grep bash|column -t
openssl version
#	rpm -qa --last|grep openssh|column -t
#	rpm -qa --last|grep openssl|column -t
rpm -qa --last|grep ntp|column -t
}

function getother1Status(){
echo ""
echo -e "###多路径冗余状态检查"
systemctl status multipathd 2>/dev/null
multipath -ll 2>/dev/null
echo ""
echo  -e "###系统内核参数"
sysctl -p
echo ""
echo  -e "###开机挂载检查"
egrep -v '^#|^$' /etc/fstab
echo ""
}



function getHowLongAgo(){
# 计算一个时间戳离现在有多久
datetime="$*"
[ -z "$datetime" ] && echo `stat /etc/passwd|awk "NR==6"`
Timestamp=$(date +%s -d "$datetime")
Now_Timestamp=$(date +%s)
Difference_Timestamp=$(($Now_Timestamp-$Timestamp))
days=0;hours=0;minutes=0;
sec_in_day=$((60*60*24));
sec_in_hour=$((60*60));
sec_in_minute=60
while (( $(($Difference_Timestamp-$sec_in_day)) > 1 ))
do
let Difference_Timestamp=Difference_Timestamp-sec_in_day
let days++
done
while (( $(($Difference_Timestamp-$sec_in_hour)) > 1 ))
do
let Difference_Timestamp=Difference_Timestamp-sec_in_hour
let hours++
done
echo "$days 天 $hours 小时前"
}

function getUserLastLogin(){
username=$1
: ${username:="`whoami`"}
thisYear=$(date +%Y)
oldesYear=$(last | tail -n1 | awk '{print $NF}')
while(( $thisYear >= $oldesYear));do
loginBeforeToday=$(last $username | grep $username | wc -l)
loginBeforeNewYearsDayOfThisYear=$(last $username -t $thisYear"0101000000" | grep $username | wc -l)
if [ $loginBeforeToday -eq 0 ]
then
echo "从未登录过"
break
elif [ $loginBeforeToday -gt $loginBeforeNewYearsDayOfThisYear ]
then
lastDateTime=$(last -i $username | head -n1 | awk '{for(i=4;i<(NF-2);i++)printf"%s ",$i}')" $thisYear"
lastDateTime=$(date "+%Y-%m-%d %H:%M:%S" -d "$lastDateTime")
echo "$lastDateTime"
break
else
thisYear=$((thisYear-1))
fi
done

}

function getState(){
if [[ $centosVersion < 7 ]]
then
if [ -e "/etc/init.d/$1" ]
then
if [ `/etc/init.d/$1 status 2>/dev/null | grep -E "is running|正在运行" | wc -l` -ge 1 ]
then
r="active"
else
r="inactive"
fi
else
r="unknown"
fi
else
#CentOS 7+
r="$(systemctl is-active $1 2>&1)"
fi
echo "$r"
}

function getSelinux(){
echo -e "###关闭防火墙和selinux检查"
if [[ $os_version == 7 ]]
then
systemctl status firewalld 2>/dev/null
systemctl status NetworkManager 2>/dev/null
getenforce
elif [[ $os_version == 6 ]]
then
/etc/init.d/firewalld status  2>/dev/null
/etc/init.d/NetworkManager status 2>/dev/null
getenforce
fi
echo ""
}

function getHost(){
echo -e "###更改主机名和解析检查"
hostname
echo ""
ip a
echo ""
cat /etc/hosts
echo ""
}

function getYum(){
echo -e "###配置YUM源检查"
yum repolist
echo ""
}

function getSSH_speed(){
echo -e "###SSH加速调整检查"
cat /etc/ssh/sshd_config | grep "UseDNS no"
echo ""
}

function getlimits_config(){
echo -e "###系统限制修改检查"
tail -20 /etc/security/limits.conf
echo ""
}

function getsysctl_config(){
echo -e "###系统内核参数检查"
tail -25 /etc/sysctl.conf
echo ""
}

function getprofile_config(){
echo -e "###系统环境变量检查"
tail -10 /etc/profile
echo ""
}

function gettransparent_hugepage_config(){
echo -e "###透明大页关闭检查"
grep Huge /proc/meminfo
echo ""
}

function getscheduler_config(){
echo -e "###存储调度算法检查"
cat /sys/block/*/queue/scheduler
echo ""

}



#执行检查并保存检查结果

function save_check(){

echo "+++++++++++++++++++++++++Hardware Info+++++++++++++++">>$RESULTFILE
dmidecode -t 1 >>$RESULTFILE
echo "+++++++++++++++++++++++++SSH Info+++++++++++++++">>$RESULTFILE
ssh -V >>$RESULTFILE
echo ""
echo "+++++++++++++++++++++++++HA Info+++++++++++++++">>$RESULTFILE
cat /etc/cluster/cluster.conf >>$RESULTFILE
clustat -l >>$RESULTFILE
echo ""

}


function check(){

version
getSystemStatus
getCpuStatus
getMemStatus
getDiskStatus
getNetworkStatus
getListenStatus
getProcessStatus
getServiceStatus
getulimitStatus
getAutoStartStatus
getLoginStatus
getCronStatus
getUserStatus
getPasswordStatus
getSudoersStatus
getJDKStatus
getFirewallStatus
#getSSHStatus
getotherStatus
getInstalledStatus
getother1Status
getSelinux
getHost
getYum
getSSH_speed
getlimits_config
getsysctl_config
getprofile_config
getscheduler_config
gettransparent_hugepage_config
#save_check

}


##############################进度条##############################
progress_bar() {

{
for ((i = 0 ; i <= 100 ; i+=20)); do
sleep 1
echo $i
done
} | whiptail --gauge "Please wait while installing" 6 60 0

}


##############################欢迎页##############################
if (whiptail --title "上海维致信息技术有限公司-高原" --yes-button "开始" --no-button "退出"  --yesno "       欢迎您使用操作系统初始化程序，请问要现在开始么？" 10 65) then
green '========================================================='
echo ""
echo ""
else
blue '您选择了退出,期待您的下次使用！'
echo ""
echo ""
exit
fi


DISTROS=$(whiptail --title "上海维致信息技术有限公司-高原" --checklist \
"            请选择你要执行的操作：" 27 50 20 \
"1" "关闭防火墙和Selinux" OFF \
"2" "停止不必要系统服务" OFF \
"3" "配置IP和BOND" OFF \
"4" "更改主机名和解析" OFF \
"5" "配置YUM源" OFF \
"6" "安装系统常用安装包" OFF \
"7" "配置NTP客户端" OFF \
"8" "SSH加速调整" OFF \
"9" "系统资源限制修改" OFF \
"10" "系统内核参数" OFF \
"11" "系统全局环境变量" OFF \
"12" "透明大页关闭" OFF \
"13" "磁盘调度算法" OFF \
"14" "ORACLE用户设置" OFF \
"15" "ORACLE目录设置" OFF \
"16" "ORACLE环境变量修改" OFF \
"17" "收集系统信息" OFF \
"18" "全局系统基础初始化" OFF \
"19" "全局ORACLE初始化" OFF \
"20" "EXIT" OFF 3>&1 1>&2 2>&3)

exitstatus=$?

OIFS=$IFS; IFS=" "; set -- $DISTROS; aa=$1;bb=$2;cc=$3;dd=$4;ee=$5;ff=$6;gg=$7;hh=$8;ii=$9;jj=$10;kk=$11;ll=$12;mm=$13;nn=$14;oo=$15;pp=$16;qq=$17;rr=$18;ss=$19;tt=$20; IFS=$OIFS

for i in $aa $bb $cc $dd $ee $ff $gg $hh $ii $jj $kk $ll $mm $nn $oo $pp $qq $rr $ss $tt
do
case $i in
'"1"')
close_firewalld_selinux
;;
'"2"')
stop_os_service
;;
'"3"')
config_ip_bond
;;
'"4"')
hosts_config
;;
'"5"')
yum_config
;;
'"6"')
install_packages
;;
'"7"')
config_ntp_client
;;
'"8"')
ssh_adjust
;;
'"9"')
limits_config
;;
'"10"')
sysctl_config
;;
'"11"')
all_profile_config
;;
'"12"')
transparent_hugepage_config
;;
'"13"')
scheduler_config
;;
'"14"')
oracle_user_config
;;
'"15"')
oracle_dir_config
;;
'"16"')
oracle_profile_config
;;
'"17"')
echo -e '\e[1;35m17、系统信息收集中，请稍后……………………………………\e[0m\n'
check > $RESULTFILE
echo -e "\033[44;37m检查结果存放在：\033[0m"
echo -e "\033[42;37m$RESULTFILE \033[0m"
;;
'"18"')
close_firewalld_selinux
stop_os_service
config_ip_bond
hosts_config
yum_config
install_packages
config_ntp_client
ssh_adjust
limits_config
sysctl_config
all_profile_config
transparent_hugepage_config
scheduler_config
echo -e '\e[1;35m17、系统信息收集中，请稍后……………………………………\e[0m\n'
check > $RESULTFILE
echo -e "\033[44;37m检查结果存放在：\033[0m"
echo -e "\033[42;37m$RESULTFILE \033[0m"
;;
'"19"')
oracle_user_config
oracle_dir_config
oracle_profile_config
echo -e '\e[1;35m17、系统信息收集中，请稍后……………………………………\e[0m\n'
check > $RESULTFILE
echo -e "\033[44;37m检查结果存放在：\033[0m"
echo -e "\033[42;37m$RESULTFILE \033[0m"
;;
'"20"')
echo ""
echo ""
blue '您选择了退出,期待您的下次使用！'
exit
;;
esac

done

#!/bin/bash
set -e

sshd_config_file="/etc/ssh/sshd_config"

function show_usage() {
	echo "usage :
	$SHELLNAME help                        显示帮助
	$SHELLNAME change_ssh_port [2222]      修改随机ssh端口
	$SHELLNAME install_ss_py               安装ss-python
	$SHELLNAME install_ss_libv             安装ss-libv
	$SHELLNAME add_server_py               添加ss-python服务
	$SHELLNAME add_server_libv             添加ss-libv服务"
}

[ $# -eq 0 ] && { show_usage ;	exit 1 ; }

function change_ssh_port() {
	if [ ! -n "$1" ] ;then
		new_ssh_port=$((RANDOM%20000+10000))
	else
		new_ssh_port=$1
	fi
	sed -i "s/#\?Port\s[[:digit:]]\+/Port $new_ssh_port/g" $sshd_config_file
	service sshd restart
	echo "新的端口 = $new_ssh_port"
	echo "请使用命令 ssh root@ip -p $new_ssh_port 登录服务器"
}

function install_ss_py() {
	echo "安装依赖库"
	yum install -q -y python-setuptools && easy_install pip && pip install --upgrade pip
	echo "安装shadowsocks"
	pip install shadowsocks
	echo "Success!"
}

function install_ss_libv() {
	echo "安装依赖库"
	yum groupinstall -q -y "Development Tools"
	yum install -q -y epel-release
	yum install -q -y wget pcre-devel asciidoc xmlto mbedtls-devel libsodium-devel libev-devel
	echo "git clone libudns"
	git clone https://github.com/shadowsocks/libudns.git
	cd libudns \
	&& ./autogen.sh \
	&& ./configure \
	&& make \
	&& make install \
	&& cd .. \
	&& rm -rf libudns
	echo "git clone ss"
	git clone https://github.com/shadowsocks/shadowsocks-libev.git
	cd shadowsocks-libev
	git submodule update --init --recursive \
	&& ./autogen.sh \
	&& ./configure \
	&& make \
	&& make install \
	&& cd .. \
	&& rm -rf shadowsocks-libev
	echo "Success!"
}


function add_server_py() {
	port=$((RANDOM%50000+30000))
	method=$(get_method)
	passwd=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
	echo "----server-new--"
	echo "port=$port"
	echo "method=$method"
	echo "passwd=$passwd"
	echo "----server-end--"
	cmd="ssserver -p $port -k $passwd -m $method --fast-open --workers 5 --pid-file /tmp/$port.pid --log-file /tmp/$port.log --user nobody -d start"
	add_on_start $cmd
	$cmd
}

function add_server_libv() {
	port=$((RANDOM%50000+30000))
	method=$(get_method libv)
	passwd=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
	echo "----server-new--"
	echo "port=$port"
	echo "method=$method"
	echo "passwd=$passwd"
	echo "----server-end--"
	cmd="ss-server -p $port -k $passwd -m $method --fast-open -u -f /tmp/$port.pid"
	add_on_start $cmd
	$cmd
}

function install_chacha() {
	yum groupinstall -q -y "Development Tools"
	yum install -q -y wget
	lib_ver="1.0.11"
	wget https://github.com/jedisct1/libsodium/releases/download/$lib_ver/libsodium-$lib_ver.tar.gz
	tar xf libsodium-$lib_ver.tar.gz && cd libsodium-$lib_ver
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
}

function add_on_start() {
	chmod a+x /etc/rc.local
	echo $@ >> /etc/rc.local
	echo "add success"
}

function get_method() {
	if [ ! -n "$1" ] ;then
		method=(aes-256-cfb rc4-md5 salsa20 aes-192-cfb chacha20)
	else
		method=(aes-256-cfb rc4-md5 salsa20 aes-192-cfb chacha20 aes-256-gcm aes-256-ctr camellia-256-cfb chacha20-ietf chacha20-ietf-poly1305)
	fi
	num=${#method[@]}
	a=$[RANDOM%$num]
	echo ${method[$a]}
}


case "$1" in
	"help")
		show_usage
		;;

	"change_ssh_port")
		shift
		change_ssh_port $1
		;;

	"install_ss_py")
		shift
		install_ss_py
		;;

	"install_ss_libv")
		shift
		install_ss_libv
		;;

	"add_server_py")
		shift
		add_server_py
		;;

	"add_server_libv")
		shift
		add_server_libv
		;;
	*)
		show_usage
		;;	

esac
exit 0
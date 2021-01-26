#!/bin/sh
##添加阿里云的yum源
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

vim /etc/yum.repos.d/ceph.repo

[ceph]
name=ceph
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/x86_64/
gpgcheck=0
priority=1

[ceph-noarch]
name=ceph-noarch
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch/
gpgcheck=0
priority=1

[ceph-source]
name=ceph-source
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/SRPMS
gpgcheck=0
priority=1



yum makecache

###admin节点免密登录node节点，有sudo权限
yum install -y ceph-deploy ceph ceph-radosgw snappy leveldb gdisk python-argparse gperftools-libs python2-pip python34-pip-8.1.2-14.el7.noarch ntp
pip3.4 install pecan werkzeug flask jwt route cherrypy
yum erase firewalld* -y
####主节点
#主节点免密登录
ssh-copy-id -i ~/.ssh/id_rsa.pub root@ceph1
mkdir -p /data/ceph-cluster
cd /data/ceph-cluster
ceph-deploy new ceph1 ceph2 ceph3

###初始化监控
ceph-deploy mon create-initial
######添加磁盘并创建osd
ceph-deploy disk zap ceph1 /dev/sdb
ceph-deploy disk zap ceph2 /dev/sdb
ceph-deploy disk zap ceph3 /dev/sdb
ceph-deploy osd create --data  /dev/sdb  ceph1
ceph-deploy osd create --data  /dev/sdb  ceph2
ceph-deploy osd create --data  /dev/sdb  ceph3
#############
scp -r ceph.client.admin.keyring ceph1:/etc/ceph/
scp -r ceph.client.admin.keyring ceph2:/etc/ceph/
scp -r ceph.client.admin.keyring ceph3:/etc/ceph/
chmod 644 /etc/ceph/ceph.client.admin.keyring
######################创建mon（一般为奇数个，此处为三个）
ceph-deploy --overwrite-conf mon create ceph1
ceph-deploy --overwrite-conf admin ceph1
ceph-deploy --overwrite-conf mon create ceph2
ceph-deploy --overwrite-conf admin ceph2
ceph-deploy --overwrite-conf mon create ceph3
ceph-deploy --overwrite-conf admin ceph3
ceph-deploy mgr create ceph1
ceph-deploy mgr create ceph2
ceph-deploy mgr create ceph3

##########部署MDS（CephFS）当使用CephFS的时候才需要安装
ceph-deploy mds create ceph1 ceph2 ceph3

#########安装dashboard

1、在每个mgr节点安装
# yum install ceph-mgr-dashboard -y
2、开启mgr功能
# ceph mgr module enable dashboard
3、生成并安装自签名的证书
# ceph dashboard create-self-signed-cert  
4、创建一个dashboard登录用户名密码
# ceph dashboard ac-user-create admin chinapex administrator 
5、查看服务访问方式
# ceph mgr services



########创建pool为客户端使用
ceph osd create pool ${poolname} ${pg_num} ${pgp_num}
小于5个osd设置pg_num为128
5到10个osd设置pg_num为512
10到50个osd设置pg_num为1024
如果超过50个osd你需要自己明白权衡点，并且能自行计算pg_num的数量


##例如:创建一个chinapex的pool
ceph osd pool create chinapex 64


#针对pool创建客户端账号
ceph auth get-or-create client.chinapex mon 'allow r' osd 'allow class-read object_prefix rbd_children,allow rwx pool=chinapex'

##查看客户端账号信息
ceph auth get client.chinapex
ceph auth get-key client.chinapex | base64

###导出客户端keyring
ceph auth get client.chinapex -o ./ceph.client.chinapex.keyring

###pool启动RBD
ceph osd pool application enable chinapex rbd   ###use 'ceph osd pool application enable <pool-name> <app-name>', where <app-name> is 'cephfs', 'rbd', 'rgw', or freeform for custom applications
###创建rbd块设备,chinapex为pool名称，chinapexrbd为块名称
rbd create chinapex/chinapexrbd --size 10240
####创建快照
rbd snap create --snap mysnap chinapex/chinapexrbd
####回滚快照
rbd snap rollback chinapex/chinapexrbd


###ceph客户端使用
yum install -y ceph-common
ceph -s
rbd  map  chinapex/chinapexrbd
lsblk
rbd showmapped





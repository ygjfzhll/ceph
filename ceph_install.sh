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
yum install -y ceph-deploy ceph ceph-radosgw snappy leveldb gdisk python-argparse gperftools-libs python2-pip python34-pip-8.1.2-14.el7.noarch
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
#禁用https
ceph config set mgr mgr/dashboard/ssl false  
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

#服务端resize
rbd resize --size 30000 chinapex/chinapexrbd
#客户端ceph image扩容
xfs_growfs /dev/rbd0






####cephfs文件系统应用
清理删除 cephfs
systemctl stop ceph-mds@$HOSTNAME  
systemctl status ceph-mds@$HOSTNAME 

查看cephfs 信息
## ceph fs ls 
## ceph mds stat

## ceph mon dump
dumped monmap epoch 1
##设置mds状态为失败
ceph mds fail 0    
##删除mds文件系统
ceph fs rm leadorfs --yes-i-really-mean-it      
##删除元数据文件夹
ceph osd pool delete cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it   
ceph osd pool delete cephfs_data cephfs_data --yes-i-really-really-mean-it   
再次查看集群状态
## ceph mds stat
## eph mds  dump

#重建 cephfs
#启动所有mds服务
systemctl start ceph-mds@$HOSTNAME
systemctl status ceph-mds@$HOSTNAME

#验证：
ceph mds stat

###重建cephfs
ceph osd pool create cephfs_data 512
ceph osd pool create cephfs_metadata 512
ceph fs new ptcephfs cephfs_metadata cephfs_data
##验证集群状态
## ceph mds stat
## ceph mds dump


#集群健康状态
ceph -w


##########挂载CephFS （客户端节点执行）
##ceph auth get-or-create client.admin，获取secret
mount -t ceph 192.168.234.133:6789,192.168.234.134:6789,192.168.234.135:6789:/ /cephfs/ -o name=admin,secret=AQALog9g8suNBxAA8S57o7Rs7N/GQPi7F6MQ3w==










##########ceph对象存储搭建及使用
###安装ceph-radosgw 软件包到 ceph1 中
ceph-deploy install --rgw ceph1
##将配置文件、密钥文件同步到 ceph-e
ceph-deploy --overwrite-conf admin ceph1
###启动一个RGW服务
ceph-deploy rgw create ceph1

###修改RGW的默认端口（默认7480）
vim /etc/ceph/ceph.conf  ###末尾追加
[client.rgw.ceph1]
host = ceph1
rgw_frontends = "civetweb port=80"

##重启服务
systemctl restart ceph-radosgw.target


###使用第三方软件访问
#登陆 ceph1（RGW）创建用户
radosgw-admin user create --uid="radosgw" --display-name="First User" --system
###记住如下信息
    "keys": [
        {
            "user": "radosgw",
            "access_key": "B8A4ICWZ5310TI90A2EY",
            "secret_key": "ZHB7oYyBfeyVMdCgOpaRq9LUh1cjiGfMFozShQXJ"
        }

#####授权用户，允许 radosgw 读写 users 信息：
radosgw-admin caps add --uid=radosgw --caps="users=*"

####允许 radosgw 读写所有的usage信息：
radosgw-admin caps add --uid=radosgw --caps="usage=read,write"

###创建子用户，做为后面 swift 客户端访问时使用
radosgw-admin subuser create --uid=radosgw --subuser=radosgw:swift --access=full
####创建子用户密钥
radosgw-admin key create --subuser=radosgw:swift --key-type=swift --gen-secret
#####记住如下信息
   "swift_keys": [
        {
            "user": "radosgw:swift",
            "secret_key": "5pJjBi1aWdeVW3qzsOLN6AEF2Pn5I9trAtSunY7Z"
        }



#####客户端使用
#在 ceph-client 安装 s3 客户端软件
yum -y install s3cmd.noarch

s3cmd --configure


[root@ceph-client ~]# s3cmd --configure

Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3. Leave them empty for using the env variables.
Access Key: B8A4ICWZ5310TI90A2EY
Secret Key: ZHB7oYyBfeyVMdCgOpaRq9LUh1cjiGfMFozShQXJ
Default Region [US]: 

Use "s3.amazonaws.com" for S3 Endpoint and not modify it to the target Amazon S3.
S3 Endpoint [s3.amazonaws.com]: 192.168.234.133

Use "%(bucket)s.s3.amazonaws.com" to the target Amazon S3. "%(bucket)s" and "%(location)s" vars can be used
if the target S3 system supports dns based buckets.
DNS-style bucket+hostname:port template for accessing a bucket [%(bucket)s.s3.amazonaws.com]: %(bucket)s.192.168.234.133 bucket

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password: 
Path to GPG program [/usr/bin/gpg]: 

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP, and can only be proxied with Python 2.7 or newer
Use HTTPS protocol [Yes]: no

On some networks all internet access must go through a HTTP proxy.
Try setting it here if you can't connect to S3 directly
HTTP Proxy server name: 

New settings:
  Access Key: B8A4ICWZ5310TI90A2EY
  Secret Key: ZHB7oYyBfeyVMdCgOpaRq9LUh1cjiGfMFozShQXJ
  Default Region: US
  S3 Endpoint: 192.168.234.133
  DNS-style bucket+hostname:port template for accessing a bucket: %(bucket)s.192.168.234.133 bucket
  Encryption password: 
  Path to GPG program: /usr/bin/gpg
  Use HTTPS protocol: False
  HTTP Proxy server name: 
  HTTP Proxy server port: 0

Test access with supplied credentials? [Y/n] y
Please wait, attempting to list all buckets...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Not configured. Never mind.

Save settings? [y/N] y
Configuration saved to '/root/.s3cfg'



########dashboard启用RGW
#查看key
radosgw-admin user info --uid=radosgw
ceph dashboard set-rgw-api-access-key B8A4ICWZ5310TI90A2EY
ceph dashboard set-rgw-api-secret-key ZHB7oYyBfeyVMdCgOpaRq9LUh1cjiGfMFozShQXJ
ceph dashboard set-rgw-api-ssl-verify False








#############添加节点机器及osd
ceph-deploy new ceph1 ceph2 ceph3 ceph-client
ceph-deploy disk zap ceph-client /dev/sdb
ceph-deploy osd create --data  /dev/sdb  ceph-client
scp -r ceph.client.admin.keyring ceph.conf ceph-client:/etc/ceph/
ceph-deploy --overwrite-conf mon create ceph-client
ceph-deploy --overwrite-conf admin ceph-client
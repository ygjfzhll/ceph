一、背景介绍
ceph 版本为L版，集群由于异常断电，导致文件丢失，ceph mon 数据文件store.db/目录下的sst 文件丢失，所以无法正常启动。

本集群有三台mon节点，其中有一台mon 节点的服务可以正常启动，另外两台无法正常启动。（ceph-mon 命令已经无法执行）

二、 解决过程
因为判断可能出现文件丢失导致的mon无法启动，所以决定重做另两台mon来解决问题

1、本环境中control3的mon是好的，control1和control2是坏的

在control3上导出monmap

[root@control3 ~]monmaptool  --create  --clobber  --fsid  f1675dce-faf2-45a2-b6e3-340e8a94f13d  --add  ceph1  192.168.234.133:6789  --add  ceph2 192.168.234.134:6789    --add  ceph3 192.168.234.135:6789  --add  ceph4 192.168.234.136:6789 --add  ceph-client 192.168.234.250:6789 /tmp/monmap    
//导出monmap,好的节点写再前面，后面把所有的坏的节点加上即可。
2、将ceph4 和ceph-client节点上的/var/lib/ceph/mon目录删掉，因为仅仅是文件丢失，并不是认证出现问题，原有的/etc/ceph/目录没有删除。

3、将keyring 文件传到其他节点上

[root@control3 ~]scp   /var/lib/ceph/mon/ceph1/keyring   root@control1:/tmp/
[root@control3 ~]scp   /var/lib/ceph/mon/ceph1/keyring   root@control2:/tmp/
[root@control3 ~]scp   /tmp/monmap  root@control1:/tmp/
[root@control3 ~]scp   /tmp/monmap  root@control2:/tmp/
4、重做control1和control2的mon,在新加节点执行

[root@control1 ~] ceph-mon  --cluster ceph  -i  ceph4 --mkfs  --monmap  /tmp/monmap  --keyring  /tmp/keyring  -c  /etc/ceph/ceph.conf
[root@control1 ~] chown -R ceph:ceph   /var/lib/ceph/mon
[root@control1 ~] systemctl restart ceph-mon@ceph4

-------------------------------------------------------------------------
[root@control2 ~] ceph-mon  --cluster  ceph  -i  ceph-client --mkfs  --monmap  /tmp/monmap  --keyring  /tmp/keyring  -c  /etc/ceph/ceph.conf
[root@control2 ~] chown -R ceph:ceph   /var/lib/ceph/mon
[root@control2 ~] systemctl restart ceph-mon@ceph-client
5、执行ceph -s
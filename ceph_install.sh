#!/bin/bash

####添加阿里云的yum源
vim /etc/yum.repos.d/ceph.repo

[ceph]
name=ceph
baseurl=http://download.ceph.com/rpm-luminous/el7/x86_64/
gpgcheck=0
[ceph-noarch]
name=cephnoarch
baseurl=http://download.ceph.com/rpm-luminous/el7/noarch/
gpgcheck=0
[ceph-source]
name=cephsource
baseurl=http://download.ceph.com/rpm-luminous/el7/x86_64/
gpgcheck=0
[ceph-radosgw]
name=cephradosgw
baseurl=http://download.ceph.com/rpm-luminous/el7/x86_64/
gpgcheck=0

yum makecache

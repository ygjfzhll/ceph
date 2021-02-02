#####ceph dashboard启用监控
yum install rbd-mirror -y
systemctl enable ceph-rbd-mirror.target
systemctl start ceph-rbd-mirror.target


#vim /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://mirrors.cloud.tencent.com/grafana/yum/el7/
enabled=1
gpgcheck=0


yum install grafana -y

#vim /etc/grafana/grafana.ini

default_theme = light
[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer

#systemctl start grafana-server.service 
#systemctl status grafana-server.service 
#systemctl enable grafana-server.service

安装grafana插件。

#grafana-cli plugins install vonage-status-panel
#grafana-cli plugins install grafana-piechart-panel

重启grafana服务。

#systemctl restart grafana-server


########安装prometheus下载解压
mkdir /etc/prometheus
mv prometheus-2.13.1.linux-amd64/* /etc/prometheus
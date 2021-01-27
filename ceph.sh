#!/bin/bash
rbd map chinapex/chinapexrbd
mount /dev/rbd0 /data
mount -t ceph 192.168.234.133:6789,192.168.234.134:6789,192.168.234.135:6789:/ /cephfs/ -o name=admin,secret=AQALog9g8suNBxAA8S57o7Rs7N/GQPi7F6MQ3w==

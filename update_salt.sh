#!/bin/bash
#################################################
#此脚本用于批量升级Saltstack版本
#作者：zhangjian@lingrengame.com
#时间：2020-11-21 11：27：00
#################################################
#升级master端salt
wget -O - https://repo.saltstack.com/apt/ubuntu/18.04/amd64/2019.2/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
echo 'deb http://repo.saltstack.com/apt/ubuntu/16.04/amd64/2019.2 xenial main' > /etc/apt/sources.list.d/saltstack.list
apt-get update
#EOF中的N表示不替换原有的配置文件
apt-get install -y salt-master << EOF
N
N
EOF
systemctl restart salt-master salt-minion
#升级minion端salt
#/tmp/iplist为其他脚本生成的信息文件，首列IP，次列主机名
for ip in `cat /tmp/iplist | grep -v ops | awk '{print $1}'`
do
        tgt=`cat /tmp/iplist | grep $ip | awk '{print $2}'`
        opt1="wget -O - https://repo.saltstack.com/apt/ubuntu/18.04/amd64/2019.2/SALTSTACK-GPG-KEY.pub | sudo apt-key add - && \
             echo 'deb http://repo.saltstack.com/apt/ubuntu/16.04/amd64/2019.2 xenial main' > /etc/apt/sources.list.d/saltstack.list && \
             apt-get update && apt-get install -y salt-minion << EOF
             N
             EOF"
        opt2="systemctl restart salt-minion"
        ssh $ip "$opt1"
        if [[ $? -eq 0 ]]; then
                echo -e "\033[1;32m$tgt upgrade success. \033[0m"
                echo "$tgt upgrade success" >> upgrade_success.log
        else
                echo -e "\033[1;31m$tgt upgrade failed,please check. \033[0m"
                echo "$tgt upgrade failed" >> upgrade_fail.log
        fi
        ssh $ip "$opt2"
done
echo -e "\033[1;33mStart collecting salt version information... \033[0m"
sleep 2
salt '*' grains.get saltversion

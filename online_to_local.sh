#!/bin/bash
################################################################################
#	此脚本用于将线上地区历史备份sql导入指定测试服,参数格式如下:
#	./online_to_local.sh 线上zone_id 备份时间(20201210) 测试zone_id
#	./online_to_local.sh 109 20201210 912
#	Power by zhangjian@lingrengame.com 2020-12-08 16:53:00
################################################################################

online_zone=$1
bak_time=$2
target_zone=$3
local_path='/data/mysqldump/old_bak_mysql'
remote_path="/data/gameapp/game$target_zone"
if [[ $target_zone == '912' ]];then
	dbhost='10.23.57.22'
	dbuser='saier'
	dbpass='Lr@2019!saiER'
elif [[ $target_zone == '913']];then
	dbhost='10.23.57.31'
	dbuser='root'
	dbpass='lingren@123'
fi

#下载备份
Get_File(){
	ossutil64 cp -rf oss://cp-statics-sg/product-2010403/DBbackup-nx_base-sg/nx_base_"$online_zone"/"$bak_time"040001.sql.gz $local_path
	ret=`ls $local_path | wc -l`
	#备份文件名会有两种可能
	if [[ $ret -eq 0 ]];then
		ossutil64 cp -rf oss://cp-statics-sg/product-2010403/DBbackup-nx_base-sg/nx_base_"$online_zone"/"$bak_time"040002.sql.gz $local_path
		cd $local_path && gunzip "$bak_time"040002.sql.gz
	fi
	cd $local_path && gunzip "$bak_time"040001.sql.gz
	if [[ $? -eq 0 ]];then
		echo "nx_base_$online_zone bak sql download success..."
	else
		echo "nx_base_$online_zone bak sql download failed..."
		exit 1
	fi
}

#清档
Reset_Db(){
	mysql -u"$dbuser" -p"$dbpass" -h"$dbhost" -e "drop database nx_base_$target_zone;"
	mysql -u"$dbuser" -p"$dbpass" -h"$dbhost" -e "CREATE DATABASE IF NOT EXISTS nx_base_$target_zone DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
	mysql -u"$dbuser" -p"$dbpass" -h"$dbhost" nx_base_$target_zone < /data/salt/scripts/sql_scripts/nx_base.sql
	for i in `ls $local_path`
	do
		mysql -u"$dbuser" -p"$dbpass" -h"$dbhost" nx_base_$target_zone < $local_path/$i
	done
	if [[ $? -ne 0 ]];then
		echo "reset $target_zone db failed..."
		exit 1
	else
		echo "reset $target_zone db success..."
	fi
	mv $local_path/$i /data/mysqldump/
}

#修改serverid并重启服务器
Server_Ctl(){
	ssh $dbhost "cp $remote_path/gen_config.sh_bak $remote_path/gen_config.sh && sed -i 's/server_ids/$online_zone/' $remote_path/gen_config.sh"
	ssh $dbhost "cd $remote_path && ./gen_server.sh fkill && rm -rf log/* && rm -rf udb/* && ./gen_server.sh init && ./gen_server.sh start"
	if [[ $? -ne 0 ]];then
		echo "start $target_zone failed..."
		exit 1
	else
		echo "start $target_zone success..."
	fi
}

Get_File
Reset_Db
Server_Ctl

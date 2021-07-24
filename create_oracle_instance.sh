#!/bin/bash

# 想要新建的实例名称
INSTANCE_NAME='YOUR_INSTANCE_NAME'
# 可用区域
AVAILABILITY_DOMAIN='YOUR_AVAILABILITY_DOMAIN'
# 镜像ID
IMAGE_ID='YOUR_IMAGE_ID'
# 子网ID
SUBNET_ID='YOUR_SUBNET_ID'
# 实例机型
SHAPE='YOUR_SHAPE'
# CPU数
OCPUS=4
# 内存数GB
MEMORY_SIZE=24
# 启动硬盘空间GB
BOOT_VOL_SIZE=100
# SSH认证公钥
SSH_AUTH_KEY='YOUR_SSH_AUTH_KEY'

#server酱开关，0为关闭，1为server酱，2为telegram
NOTIFICATION=0
#server酱参数
SERVERCHAN_KEY='YOUR_SERVERCHAN_KEY'
#telegram参数
BOT_TOKEN='YOUR_BOT_TOKEN'
USERID=YOUR_USERID

# 此行以下不用修改

ERRORCODE=(400 401 403 404 405 409 412 413 422 429 431 500 501 503)

option="${1}"
case $option in
	-c) 
		CONFIG_FILE="${2}"
		;;
	*)
		CONFIG_FILE='/root/.oci/config'
		;;
esac

userId=$(oci iam user list --config-file $CONFIG_FILE | jq -r '.[][0]."id"')
compartmentId=$(oci iam user list --config-file $CONFIG_FILE | jq -r '.[][0]."compartment-id"')

echo -e '*****************************************************************'
echo -e '***************************** START *****************************'
echo -e '*****************************************************************'

#定义主进程
function main {

	oci compute instance launch --availability-domain $AVAILABILITY_DOMAIN --image-id $IMAGE_ID --subnet-id $SUBNET_ID --shape $SHAPE --assign-public-ip true --metadata '{"ssh_authorized_keys": "'"${SSH_AUTH_KEY}"'"}' --compartment-id $compartmentId --shape-config '{"ocpus":'$OCPUS',"memory_in_gbs":'$MEMORY_SIZE',"boot_volume_size_in_gbs":'$BOOT_VOL_SIZE'}' --display-name $INSTANCE_NAME --config-file $CONFIG_FILE > res.json 2>&1
	
	sed -i '1d' res.json
	
	local responseCode=$(cat res.json | jq .status)
	
	if [[ "${array[@]}" =~ "$responseCode" ]]
		then
			echo -e 'INSTANCE CREATED SUCCESSED'
			# 发送通知
			if [ $NOTIFICATION != 0 ]
			then
				text="实例已新建成功"
				desp="您的位于${AVAILABILITY_DOMAIN}的甲骨文实例已创建成功！"
				notification "${text}" "${desp}"
			fi
			echo -e $desp
			sed -i '/create_oracle_instance.sh/d' /var/spool/cron/root
	else
			echo -e 'INSTANCE CREATED FAILED'
			echo -e 'ErrorCode='$(cat res.json | jq .code)
			echo -e 'ErrorMessage='$(cat res.json | jq .message)
	fi
	
	rm res.json -rf

}

# 定义函数发送通知
function notification {
	case $NOTIFICATION in 
		1)
			# serverchen通知
			local json=$(curl -s https://sc.ftqq.com/$SERVERCHAN_KEY.send --data-urlencode "text=$1" --data-urlencode "desp=$2")
			errno=$(echo $json | jq .errno)
			errmsg=$(echo $json | jq .errmsg)
			if [ $errno = 0 ]
			then
				echo -e 'notice send success'
			else
				echo -e 'notice send faild'
				echo -e "the error message is ${errmsg}"
			fi
			;;
		2)
			# telegram通知
			curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d "chat_id=${USERID}&text=${2}"
			;;
		*)
			exit 1
			;;
	esac
}

main
	
echo -e '*****************************************************************'
echo -e '****************************** END ******************************'
echo -e '*****************************************************************'

exit 0

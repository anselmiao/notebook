#!/bin/sh
#########
#Deploy blockchain sample service
# Global flags
path=`pwd`
localip=`ifconfig eth0 | grep "inet addr" | awk '{ print $2}' | awk -F: '{print $2}'`

#检查host文件是否存在
if [ -e ./hosts ];then
rm hosts
fi

#检查证书目录是否存在
if [ -e ./certificate ];then
rm -rf certificate
fi
#解压证书文件
echo "Start unzip certificate ...."
if command -v unzip >/dev/null 2>&1; then
  echo 'Exists unzip'
else
  echo 'Please install unzip'
  exit
fi
cerzip=$(ls|grep .zip)
for i in $cerzip;
do
unzip -n $i -d certificate/
done
echo "Unzip certificate Done!!"

#检查所需文件是否已准备完善
echo "Start check if the required files are ready"
if [ -e $path/xxx1.yaml ]&&[ -e $path/xxx2.yaml ]&&[ -e $path/xxx3.yaml ]&&[ -e $path/certificate ];then
echo "Check required files OK!!"
else
echo "Please check if the required files are ready!!"
exit
fi

#获取baas服务浮动ip
echo "Start get Eip from SDK"
eip=$(sed -n "s/.*#orderer eip: \(\S\)/\1/p" ./xxx1.yaml)
if [ -z $eip ];then
echo "Get Eip error!"
exit
else
echo "Get Eip success, Eip is $eip"
fi

#获取SDK中对应的hostname
echo "Start get hostname frome SDK"
hostname=$(sed -n "s/.*url: grpcs:\/\/\(\S\)/\1/p" ./xxx1.yaml|cut -d ':' -f 1)
for i in $hostname;
do
echo  "$eip $i" >> ./hosts;
done
peer2=$(sed -n "s/.*url: grpcs:\/\/\(\S\)/\1/p" ./xxx2.yaml|awk 'END { print $1 }'|cut -d ':' -f 1)
echo  "$eip $peer2" >> ./hosts;
peer3=$(sed -n "s/.*url: grpcs:\/\/\(\S\)/\1/p" ./xxx3.yaml|awk 'END { print $1 }'|cut -d ':' -f 1)
echo  "$eip $peer3" >> ./hosts;

hostsline=$(awk '{print NR}' ./hosts|tail -n1)
if [ $hostsline -lt 2 ];then
echo "Get hostname error,please ckeck SDK!"
exit
else
echo "Get hostname success!"
fi

#if [ -e $path/api-server.tar.gz ];then
#echo "Api-server images file already exists,Skip download!"
#else
#echo "Start Download Api-server images..."
#wget -k --no-check-certificate https://bcs.obs.cn-north-1.myhwclouds.com/fabric1.1/api-server.tar.gz
#echo "Download Api-server images file done!!"
#fi

if [ -e $path/demo-chaincode-portal2.tar.gz ];then
echo "Portal images file already exists,Skip download!"
else
echo "Start Portal Download images..."
wget -k --no-check-certificate https://bcs.obs.cn-north-1.myhwclouds.com/bcsdemo/demo-chaincode-portal2.tar.gz
echo "Download Portal images file done!!"
fi

#if [ -e $path/api-server.tar.gz ]&&[ -e $path/demo-chaincode-portal2.tar.gz ];then
if [ -e $path/demo-chaincode-portal2.tar.gz ];then
echo "Start load images..."
if [ -z $(docker images|grep api-server|grep latest|awk '{print $3}') ];then
docker pull swr.cn-north-1.myhuaweicloud.com/bcs-ansel/api-server:latest
else
echo "Api-server images is exists,Skip load!"
fi
if [ -z $(docker images|grep demo-chaincode-portal2|grep latest|awk '{print $3}') ];then
docker load -i demo-chaincode-portal2.tar.gz
else
echo "Portal images is exists,Skip load!"
fi
echo "Load images done !!!"
else
echo "Please check images files!!"
exit
fi


#启动api-server服务
echo "Start api-server ....."
docker run -p 8080:8080  -d -it -v $path/xxx1.yaml:/opt/gopath/src/github.com/hyperledger/api-server/conf/xxx1.yaml -v $path/xxx2.yaml:/opt/gopath/src/github.com/hyperledger/api-server/conf/xxx2.yaml -v $path/xxx3.yaml:/opt/gopath/src/github.com/hyperledger/api-server/conf/xxx3.yaml -v $path/certificate:/opt/gopath/src/github.com/hyperledger/api-server/conf/crypto -v $path/hosts:/etc/hosts  swr.cn-north-1.myhuaweicloud.com/bcs-ansel/api-server:latest ./api-server
echo "Start api-server success!"

if [ -z $localip ] || [[ $localip =~ ^(192\.168\.[0-9]{1,3}\.[0-9]{1,3})$ ]];then
echo "Please input this machine's Eip:"
read Arg
localip=$Arg
else
echo "Get localip is $localip"
fi

#启动前台服务
echo "Start demo-chaincode-portal2 ...."
docker run -p 4200:4200 -e API_SERVER_IP=$localip -e API_SERVER_PORT=8080 -d -it demo-chaincode-portal2:latest ./start.sh
echo "Start demo-chaincode-portal2 success!"


echo "Please login http://$localip:4200 to visit sample service!!"

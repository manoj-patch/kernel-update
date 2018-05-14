#!/bin/bash
TIMESTAMP=`date "+%Y-%m-%d"`
exec > >(tee ${TIMESTAMP}-kernlupdate.log) 2>&1
USER="aws-user1`"
SERVICE=("zookeeper.service" "kafka.service" "tomcat.service" "httpd.service")
TMPFILE1="/tmp/kernel-list.txt"
echo "Current runtime of script is at `date`"
echo

if [ -f "last-runtime.txt" ]
then
  echo "Last runtime of script is at `cat last-runtime.txt`"
else
  touch last-runtime.txt
fi

#Below function is for establishing SSH Connection with Servers#
ssh_conn() {
  sshpass -p 'User-Pass' ssh -n -o StrictHostKeyChecking=no $USER@$IPADDRESS $1
}

#To reconnect after remote server reboot
reconnect() {
    while true; do echo connecting... && ssh_conn "echo reconnecting ...." 2> /dev/null && echo connected;[ $? -eq 0 ] && break || sleep 1; done
}

#restart or reboot remote server
reboot_remote() {
    echo rebooting the node $IPADDRESS
    echo
    ssh_conn "(sleep 1 && sudo sh -c 'reboot &') && exit"
    echo .........
    sleep 2
}

kafka_zookeeper() {
  case $1 in
        zookeeper)
                zookeeper_start_sh=`ssh_conn "sudo find / -type f -name zookeeper-server-start.sh 2> /dev/null"`
                echo zookeeper_start_sh is $zookeeper_start_sh
                zookeeper_config=`ssh_conn "sudo find / -type f -name zookeeper.properties 2>  /dev/null"`
                echo zookeeper_config is $zookeeper_config
                ssh_conn "echo starting zookeeper service && (sudo $zookeeper_start_sh $zookeeper_config > /dev/null 2>&1 &)"
                ;;
        kafka)
                kafka_start_sh=`ssh_conn "sudo find / -type f -name kafka-server-start.sh 2>  /dev/null"`
                echo kafka_start_sh is $kafka_start_sh
                kafka_config=`ssh_conn "sudo find / -type f -name server.properties 2> /dev/null"`
                echo kafka_config is $kafka_config
                ssh_conn "echo starting kafka service && (sudo $kafka_start_sh $kafka_config  > /dev/null 2>&1 &)"
                break
                ;;
        *)
                echo "Sorry, I don't understand"
                ;;
  esac
}

#Below function is for updating kernel version if it's needed
kernel_check() {
    if [ $(ssh_conn "sudo yum list kernel*|grep -i available|wc -l") -eq 0 ]
    then
        echo "There is no available package to install kernel"
        echo
        echo "Installed version of Kernel is UpToDate"
        echo
        ssh_conn " echo Output of 'sudo yum list kernel*' command is;sudo yum list kernel*|sed  -n '1!p'"
        break
    elif [ $(ssh_conn "sudo yum list kernel*|grep -i available|wc -l") -eq 1 ]
    then
        INSTALLED_KERNEL=`ssh_conn "sudo uname -r"`
        ssh_conn "sudo sh -c 'yum list kernel* > $TMPFILE1'"
        AVAILABLE_KERNEL=$(ssh_conn "sudo tail -n1 $TMPFILE1|awk '{print \$1\" \"\$2}'")
        echo The Installed version of kernel is $INSTALLED_KERNEL
        echo
        echo The Available version of kernel is $AVAILABLE_KERNEL
        echo
        echo Updating the Kernel to Available version $AVAILABLE_KERNEL
        echo
        ssh_conn "sudo yum update kernel -y"
        service_stop
        reboot_remote
        reconnect
        service_start
    else
        echo There is an unexpected error
    fi
}

#To kill the running processes based on their Process Ids
kill_pid() {
    for i in $PID
    do
    ssh_conn "echo killing process $i && sudo kill $i"
    done
}

service_detect() {
    for i in "${SERVICE[@]}"
    do
      x=`echo $i|cut -d'.' -f1`
          if [ $(ssh_conn "sudo ps -ef | grep -v grep | grep $x | wc -l") -gt 0 ]
          then
              if [ $(ssh_conn "sudo systemctl | grep -v grep | grep $x | wc -l") -gt 0 ]
              then
                  echo "$i is running!!!" in $IPADDRESS
                  echo
                  REGISTER_SERVICE1+=("$i")
                  echo Elements of array REGISTER_SERVICE1 ${REGISTER_SERVICE1[@]}
              else
                  PID=$(ssh_conn "sudo ps -ef | grep -v grep | grep $x |awk '{print \$2}'")
                  echo "$i is running!!!" in $IPADDRESS
                  echo Process IDs of $x: $PID
                  echo
                  REGISTER_SERVICE2+=("$x.service")
#                  echo Elements of array REGISTER_SERVICE2 ${REGISTER_SERVICE2[@]}
              fi
          fi
    done
}

service_stop() {
    for i in "${SERVICE[@]}"
    do
      x=`echo $i|cut -d'.' -f1`
          if [ $(ssh_conn "sudo ps -ef | grep -v grep | grep $x | wc -l") -gt 0 ]
          then
              if [ $(ssh_conn "sudo systemctl | grep -v grep | grep $x | wc -l") -gt 0 ]
              then
                  echo "$i is running!!!" in $IPADDRESS
                  echo stoping the $i ....
                  ssh_conn "sudo systemctl stop $i"
#                  REGISTER_SERVICE1+=("$i")
#                  echo Elements of array REGISTER_SERVICE1 ${REGISTER_SERVICE1[@]}
              else
                  PID=$(ssh_conn "sudo ps -ef | grep -v grep | grep $x |awk '{print \$2}'")
                  echo Process IDs of $x: $PID
                  kill_pid
#                  REGISTER_SERVICE2+=("$x.service")
#                  echo Elements of array REGISTER_SERVICE2 ${REGISTER_SERVICE2[@]}
              fi
          fi
    done
}

service_start() {
          #########Starting services for array REGISTER_SERVICE1#########
          if [ -n "$REGISTER_SERVICE1" ]
          then
               for i in ${REGISTER_SERVICE1[@]}
               do
                   y=`echo $i|cut -d'.' -f1`
                   if [ $(ssh_conn "sudo ps -ef | grep -v grep | grep $y | wc -l") -eq 0 ]
                   then
                       if [ $(ssh_conn "sudo systemctl | grep -v grep | grep $y | wc -l") -eq  0 ]
                       then
                           echo "$y is expected to run but not running!!!" in $IPADDRESS
                           echo So starting the $y ....
                           ssh_conn "sudo systemctl start $y"
                       fi
                   fi
               done
            fi

           #########Starting services for array REGISTER_SERVICE2#########
          if [ -n "$REGISTER_SERVICE2" ]
          then
               for i in ${REGISTER_SERVICE2[@]}
               do
                   z=`echo $i|cut -d'.' -f1`
                   if [ $i == "kafka.service" ]
                   then
                       kafka_zookeeper $z
                   elif [ $i == "zookeeper.service" ]
                   then
                       kafka_zookeeper $z
                   else
                       echo While starting kafka zookeeper unknown error occured
                   fi
              done
          fi
}

while read line
do
    IPADDRESS=`echo $line`
    echo "Script is now executing on server $IPADDRESS"
    echo
    service_detect
    kernel_check
    echo
    unset REGISTER_SERVICE1 REGISTER_SERVICE2
done < "inventory.txt"
echo `date` > last-runtime.txt
set -x

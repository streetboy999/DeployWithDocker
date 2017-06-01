#!/bin/bash

HOSTNAME=`hostname`
USERNAME=`whoami`

for user in root `ls /home`
do
	if [ $user = "root" ]
	then
		$(pwd)/key-gen.exp &>/dev/null
	else
		su $user -l -c "$(pwd)/key-gen.exp" &>/dev/null
	fi

	for host in `cat $(pwd)/hosts.$CLUSTER_NAME | grep -v $HOSTNAME`
	do
		if [ $user = "root" ]
		then 
			$(pwd)/distr-ssh.exp ~/.ssh/id_rsa.pub $host &>/dev/null
		else
			su $user -l -c "$(pwd)/distr-ssh.exp ~/.ssh/id_rsa.pub $host" &>/dev/null
		fi
	done
done



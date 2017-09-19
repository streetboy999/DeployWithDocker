#!/bin/bash

HOSTNAME=`hostname`
USERNAME=`whoami`

#for user in root `ls /home`
# Considering the performance I only choose root to set ssh passwordless

hostNum=`cat $(pwd)/hosts.$CLUSTER_NAME | wc -l`
if [ $hostNum -gt 5 ]; then
	exit
fi

for user in root lsfadmin
do
	if [ $user = "root" ]
	then
		$(pwd)/key-gen.exp &>/dev/null
	else
		su $user -l -c "$(pwd)/key-gen.exp" &>/dev/null
	fi

	#for host in `cat $(pwd)/hosts.$CLUSTER_NAME | grep -v $HOSTNAME`
	for host in `cat $(pwd)/hosts.$CLUSTER_NAME` # Need to include the host itself
	do
		if [ $user = "root" ]
		then 
			$(pwd)/distr-ssh.exp ~/.ssh/id_rsa.pub $host &>/dev/null
		else
			su $user -l -c "$(pwd)/distr-ssh.exp ~/.ssh/id_rsa.pub $host" &>/dev/null
		fi
	done
done


# For DM+MC, all transfer nodes in each cluster have to access the data source. By default the data source is located 
# at the submission cluster - c1. So only need to set passwordless from cn-slave2-id* (n>1) to all hosts in c1. 

user="lsfadmin" # Only support lsfadmin ssh no password between transfer nodes and submission cluster nodes
# Check if this is a DM installation
if [ -d /opt/dminstalldir ]; then

	# Check if this is an MC installation
	nCluster=`ls | grep hosts | wc -l`
	# NOTE: Writing logs by each node to the same file will cause serious performance issue
	#echo "Cluster # = $nCluster" >> $(pwd)/log.$HOSTNAME
	#echo "Hostname = $HOSTNAME" >> $(pwd)/log.$HOSTNAME
	if [ $nCluster -gt 1 ]; then
		#echo "Cluster # > 1" >> $(pwd)/log.$HOSTNAME
		if [[ $HOSTNAME =~ ^c[2-9][0-9]{0,}-slave2-id* ]] # The host must meet the pattern cn-slave2-id* (n>1)
		then
			#echo "$HOSTNAME mbatches" >> $(pwd)/log.$HOSTNAME
			for host in `cat $(pwd)/hosts.c1`
			do
				#su $user -l -c "$(pwd)/key-gen.exp" &>/dev/null
				su $user -l -c "$(pwd)/distr-ssh.exp ~/.ssh/id_rsa.pub $host" &>/dev/null
				#echo "$HOSTNAME is successful to $host with ssh without a password" >> $(pwd)/log.$HOSTNAME
			done	
		fi		
	fi

fi
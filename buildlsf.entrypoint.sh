#!/bin/bash

# Env Vars
# LSF_TOP, IS_MASTER_NODE, LOCK_FILE, NO_GO, CLUSTER_NAME, IS_LAST_NODE


# Create User and UserGroup

groupadd docker

echo "root:aaa123" | chpasswd

useradd -m lsfadmin -s /bin/bash
echo "lsfadmin:aaa123" | chpasswd

for i in `seq 1 5`;do
	useradd -m user$i -s /bin/bash
	echo "user$i:aaa123" | chpasswd
done
	

# Start ssh service

# Can ssh to remote node with root
sed -i '$a\PermitRootLogin yes' /etc/ssh/sshd_config
service ssh start




# Check if the file is being edited by other process with the lock file

while [ -e $LOCK_FILE  ]; do
sleep 1
done


# If no lock file is there create a new one
#rm $LOCK_FILE
touch $LOCK_FILE



# 1. If this is the master node
if [ $IS_MASTER_NODE = "Y" ]; then 
	sed -i '$a\LSF_STRIP_DOMAIN='"$LSF_DOMAIN"'' $LSF_TOP/conf/lsf.conf
	if [ -e $NO_GO  ]; then
		rm $NO_GO
		touch $NO_GO
	else 
		touch $NO_GO
	fi
fi

# If this is a slave node or a master node, modify lsf.cluster file

## Add the host info into $LSF_TOP/lsf.cluster with the format like  
## hostname !   !   1   3.5   ()   ()   (mg)

HOSTNAME=`hostname`
HOSTSTRING="$HOSTNAME !   !   1   3.5   ()   ()   ()"

sed -i "/HOSTNAME/a ${HOSTSTRING}" $LSF_TOP/conf/lsf.cluster.$CLUSTER_NAME

rm $LOCK_FILE

# Start LSF

while [ -e $NO_GO ]; do
	if [ $IS_LAST_NODE = "Y" ]; then
		rm $NO_GO
		break
	fi
	sleep 1
done

. $LSF_TOP/conf/profile.lsf
$LSF_SERVERDIR/lsf_daemons start


#su $LSF_ADMIN

# Must keep the main process alive otherwise the conainer will exit

cd /opt/sshnopasswd
$(pwd)/ssh-nopasswd.sh
bash 

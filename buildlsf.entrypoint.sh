#!/bin/bash

# Env Vars
# LSF_TOP, IS_MASTER_NODE, LOCK_FILE, NO_GO, CLUSTER_NAME, IS_LAST_NODE


# Trap signal to judge when to start LSF

function trapSignal(){	


	# Create User and UserGroup

	groupadd docker

	echo "root:aaa123" | chpasswd

	useradd -m lsfadmin -s /bin/bash
	echo "lsfadmin:aaa123" | chpasswd

	for i in `seq 1 3`;do
		useradd -m user$i -s /bin/bash
		echo "user$i:aaa123" | chpasswd
	done
	

	# Start ssh service
	# Can ssh to remote node with root
	sed -i '$a\PermitRootLogin yes' /etc/ssh/sshd_config
	
	# Configure sudo
	cp -p /etc/sudoers /etc/sudoers.bak
	chmod 640 /etc/sudoers
	echo "lsfadmin ALL=(ALL:ALL) ALL" >> /etc/sudoers
	sed -i "/secure_path/d" /etc/sudoers
	sed -i "s/env_reset/\!env_reset/g" /etc/sudoers
	chmod 440 /etc/sudoers
	
	# Create an automatic setup file. It has two functions:
	# 1. Create a tty
	# 2. Source LSF profile
	mkdir /setup
	setupFile="/setup/setup.sh"
	touch $setupFile
	chmod 777 $setupFile
	echo '#!/bin/bash' >> $setupFile
	echo '. $LSF_TOP/conf/profile.lsf' >> $setupFile
	echo 'script -q -c "/bin/bash" /dev/null' >> $setupFile
	

	service ssh start
	
	# Start LSF
	. $LSF_TOP/conf/profile.lsf
	$LSF_SERVERDIR/lsf_daemons start
	
	# Set ssh password-less
	cd /opt/sshnopasswd
	$(pwd)/ssh-nopasswd.sh
}


trap trapSignal SIGUSR1



while [ true ];
do
    sleep 1
done



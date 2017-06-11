#!/bin/bash

# Env Vars
# LSF_TOP, JS_TOP, IS_JS_MASTER


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
	service ssh start
	
	# Start LSF
	. $LSF_TOP/conf/profile.lsf
	$LSF_SERVERDIR/lsf_daemons start
	
	# Start PM
	if [ $IS_JS_MASTER = "Y" ]; then
		. $JS_TOP/conf/profile.js
		jadmin start
	fi
	
	# Set ssh password-less
	cd /opt/sshnopasswd
	$(pwd)/ssh-nopasswd.sh
}


trap trapSignal SIGUSR1



while [ true ];
do
    sleep 1
done


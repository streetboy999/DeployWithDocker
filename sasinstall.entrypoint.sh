#!/bin/bash

### Run in a docker container to install SAS ###

#Input Env Vars: SAS_INSTALL_PACK SAS_INSTALL_ENTITLEMENT_FILE SAS_INSTALL_DIR IS_SAS 

if [ $IS_SAS = "Y" ]; then

	# Create lsfadmin. Cannot install without lsfadmin account. 
	id lsfadmin
	if [ "$?" = "1" ];then
		useradd -m lsfadmin -s /bin/bash
		echo "lsfadmin:aaa123" | chpasswd
	fi
	
	#
	tar -xvf $SAS_INSTALL_PACK -C $NFS
	cp $SAS_INSTALL_ENTITLEMENT_FILE $SAS_INSTALL_DIR/license.dat
	cd $SAS_INSTALL_DIR
	cp install.config install.config.bak

	echo "JS_TOP=$JS_TOP" >> install.config
	echo "JS_HOST=$JS_HOST" >> install.config
	echo "JS_ADMINS=$JS_ADMINS" >> install.config
	echo "LSF_INSTALL=$LSF_INSTALL" >> install.config
	echo "LSF_TOP=$LSF_TOP" >> install.config
	echo "LSF_CLUSTER_NAME=$LSF_CLUSTER_NAME" >> install.config
	echo "LSF_MASTER_LIST=$LSF_MASTER_LIST" >> install.config
	
	JSLIB="pm9.1.3.0_install/instlib"
	
	# Hack the binary type. I don't know why the script cannot get the correct binary type. 
	cp $JSLIB/binary_type.sh $JSLIB/binary_type.sh.bak
	echo "BINARY_TYPE=linux2.6-glibc2.3-x86_64" >> $JSLIB/binary_type.sh
	
	$NFS/sasinstall.exp install.config
	
	sleep 10
	
	
	# Configure LSF cluster
	sed -i '$a\LSF_STRIP_DOMAIN='"$LSF_DOMAIN"'' $LSF_TOP/conf/lsf.conf
	for((i=$HOST_NUM-1;i>=1;i--))
	do
		HOSTSTRING="slave$i  !   !   1   3.5   ()   ()   ()"
		echo "$LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME" >> /opt/debug
		sed -i "/HOSTNAME/a $HOSTSTRING" $LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME
	done
	
	# Hack profile.js 
	# NOTE: Must add \ around the double quotes. 
	# Backup the original profile.js
	cp $JS_TOP/conf/profile.js $JS_TOP/conf/profile.js.bak
	sed -i 's/BINARY_TYPE=\"fail\"/BINARY_TYPE=linux2.6-glibc2.3-x86_64/g' $JS_TOP/conf/profile.js
	
fi






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
	
	# Hack profile.js 
	# NOTE: Must add \ around the double quotes. 
	# Backup the original profile.js
	cp $JS_TOP/conf/profile.js $JS_TOP/conf/profile.js.bak
	sed -i 's/BINARY_TYPE=\"fail\"/BINARY_TYPE=linux2.6-glibc2.3-x86_64/g' $JS_TOP/conf/profile.js
	
	bash

fi




; '

#cp install.config install.config.bak

# Create lsfadmin
id lsfadmin
if [ "$?" = "1" ];then
	useradd -m lsfadmin -s /bin/bash
	echo "lsfadmin:aaa123" | chpasswd
fi
#Modify LSF installation Script

cp install.config install.config.$LSF_CLUSTER_NAME
installFile="install.config.$LSF_CLUSTER_NAME"


sed -i '$a\LSF_TOP='"${LSF_TOP}"'' $installFile
sed -i '$a\LSF_ADMINS="lsfadmin"' $installFile
sed -i '$a\LSF_CLUSTER_NAME='"$LSF_CLUSTER_NAME"'' $installFile
sed -i '$a\LSF_MASTER_LIST='"$LSF_MASTER_NAME"'' $installFile
sed -i '$a\LSF_ENTITLEMENT_FILE='"$LSF_INSTALL_ENTITLEMENT_FILE"'' $installFile
sed -i '$a\LSF_TARDIR='"$LSF_TAR_DIR"'' $installFile

# Install
# When entrypoint is called the cwd is "/"


/opt/install.exp $installFile


# Configure LSF cluster after installation
if [ $IS_MC = "N" ]; then
	sed -i '$a\LSF_STRIP_DOMAIN='"$LSF_DOMAIN"'' $LSF_TOP/conf/lsf.conf
	for((i=$HOST_NUM-1;i>=1;i--))
	do
		HOSTSTRING="slave$i  !   !   1   3.5   ()   ()   ()"
		echo "$LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME" >> /opt/debug
		sed -i "/HOSTNAME/a $HOSTSTRING" $LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME
	done
fi

if [ $IS_MC = "Y" ]; then
	echo "MC"
	# lsf.conf
	sed -i '$a\LSF_STRIP_DOMAIN='"$LSF_DOMAIN"'' $LSF_TOP/conf/lsf.conf
	
	# lsf.cluster
	for((i=$HOST_NUM-1;i>=1;i--))
	do
		HOSTSTRING="$LSF_CLUSTER_NAME-slave$i  !   !   1   3.5   ()   ()   ()"
		echo "$LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME" >> /opt/debug
		sed -i "/HOSTNAME/a $HOSTSTRING" $LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME
	done	
	
	# lsf.shared
	LSF_SHARED="$LSF_TOP/conf/lsf.shared"
	
	# Add all clusters info into lsf.shared with the format below
	# Begin Cluster
	# ClusterName     Servers
	# c1              c1-slave1
	# End Cluster

	sed -i "/Begin Cluster/, /End Cluster/{//!d}" $LSF_SHARED
	TITLE="ClusterName      Servers"
	sed -i "/Begin Cluster/a $TITLE" $LSF_SHARED
	for((i=$LSF_CLUSTER_NUM;i>=1;i--))
	do		
		CLUSTER_SERVER="c$i              c$i-master"
		sed -i "/ClusterName/a $CLUSTER_SERVER" $LSF_SHARED
	done
	
	# lsb.queues (Forward Mode)
	# Set the first cluster to be the submission cluster and the left are execution cluster
	LSB_QUEUES="$LSF_TOP/conf/lsbatch/$LSF_CLUSTER_NAME/configdir/lsb.queues"
	
	# Queue setting of the submission cluster

	if [ $LSF_CLUSTER_NAME = "c1" ]; then
		for((i=2;i<=$LSF_CLUSTER_NUM;i++))
		do
    		    SND_STR="$SND_STR RcvQ@c$i"
		done
		echo -e "\n\nBegin Queue\nQUEUE_NAME   = SndQ\nSNDJOBS_TO   = $SND_STR\nPRIORITY=30\nNICE=20\nHOSTS=none\nEnd Queue" >> $LSB_QUEUES
	# Queue setting of execution cluster(s)
	else
		RCV_STR="c1"
		echo -e "\n\nBegin Queue\nQUEUE_NAME   = RcvQ\nRCVJOBS_FROM = $RCV_STR\nPRIORITY=30\nNICE=20\nEnd Queue" >> $LSB_QUEUES
	fi	
	
fi

'




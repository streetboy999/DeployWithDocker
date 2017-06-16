#!/bin/bash

### Run in a docker container to install LSF ###
tar -zxvf $LSF_INSTALL_SCRIPT_FILE
#cd $(pwd)/lsf9.1.3_lsfinstall
cd $(pwd)/*lsfinstall
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
		#LSF9 and LSF10 have different formats of HOSTS section in lsf.cluster 
		if [ $LSF_VERSION = "9.1" ]; then
			HOSTSTRING="slave${i}-id$ID  !   !   1   3.5   ()   ()   ()"
		elif [ $LSF_VERSION = "10.1" ]; then
			HOSTSTRING="slave${i}-id$ID  !   !   1   ()"
		fi
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
		if [ $LSF_VERSION = "9.1" ]; then
			HOSTSTRING="$LSF_CLUSTER_NAME-slave${i}-id$ID  !   !   1   3.5   ()   ()   ()"
		elif [ $LSF_VERSION = "10.1" ]; then
			HOSTSTRING="$LSF_CLUSTER_NAME-slave${i}-id$ID  !   !   1   ()"
		fi
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
		CLUSTER_SERVER="c$i              c$i-master-id$ID"
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






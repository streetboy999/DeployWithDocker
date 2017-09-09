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

# Create a shared folder which can be accessed by all compute nodes. 

if [ ! -d "/opt/SHARE_DIR" ]; then
	mkdir -p /opt/SHARE_DIR
	chmod 777 /opt/SHARE_DIR
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
	
	if [ $IS_DM = "Y" ]; then
		if [ $DM_VERSION = "9.1" ]; then
			cd $LSF_TOP/9.1/install
			./patchinstall --silent -f $LSF_TOP/conf/lsf.conf /opt/dminstalldir/lsf9.1.3_linux2.6-glibc2.3-x86_64-242435.tar.Z
			cd /opt/dminstalldir/
			tar -zxvf lsf9.1.3_data_mgr-linux-x64.tar.Z
			. $LSF_TOP/conf/profile.lsf
			cd /opt/dminstalldir/lsf9.1.3_data_mgr-linux-x64
			
			cp 9.1/linux2.6-glibc2.3-x86_64/etc/dmd $LSF_SERVERDIR/
			cp 9.1/linux2.6-glibc2.3-x86_64/bin/* $LSF_BINDIR/
			cp conf/TMPL.lsf.datamanager $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			chown lsfadmin $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			cp -R man/* $LSF_BINDIR/../../man/
			cp 1986-03.com.ibm_IBM_Platform_Data_Manager_for_LSF-9.1.3.swidtag $LSF_BINDIR/../../../properties/version

			# Install the latest DM patch 330371 
			cd $LSF_ENVDIR/../9.1/install
			./patchinstall --silent -f $LSF_ENVDIR/lsf.conf /opt/dminstalldir/lsf9.1.3_linux2.6-glibc2.3-x86_64-330371.tar.Z
		
			# Configure LSF and DM
			echo "LSF_DATA_HOSTS=slave1-id$ID" >> $LSF_ENVDIR/lsf.conf
			echo "LSF_DATA_PORT=45780" >> $LSF_ENVDIR/lsf.conf

			mkdir -p /opt/$LSF_CLUSTER_NAME/dmsa

			dmconf=$LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			echo "Begin Parameters" >> $dmconf
			echo "ADMINS = lsfadmin" >> $dmconf
			echo "STAGING_AREA = /opt/$LSF_CLUSTER_NAME/dmsa" >> $dmconf
			echo "CACHE_INPUT_GRACE_PERIOD = 1440" >> $dmconf
			echo "CACHE_OUTPUT_GRACE_PERIOD = 180" >> $dmconf
			echo "CACHE_PERMISSIONS = user" >> $dmconf
			echo "QUERY_NTHREADS = 4" >> $dmconf
			echo "CACHE_ACCESSIBLE_FILES=Y" >> $dmconf
			echo "End Parameters" >> $dmconf
			
			tranq=$LSF_ENVDIR/lsbatch/$LSF_CLUSTER_NAME/configdir/lsb.queues
			echo -e "\nBegin Queue" >> $tranq
			echo "QUEUE_NAME = transfer" >> $tranq
			echo "DATA_TRANSFER = Y" >> $tranq
			echo "HOSTS = slave2-id$ID" >> $tranq
			echo "End Queue" >> $tranq

			echo "LSF_DATA_PORT=45780" >> lsf.conf


		elif [ $DM_VERSION= "10.1" ]; then
			echo "DM10.1..."
		fi
	fi
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
	
	
	## MC DM support
	# MC + DM must follow the principles as below:
	# 1. dmd can resolve each other (reserve). So a hosts file is needed if the 3rd party dns container cannot. 
	# 2. The hosts in the remote transfer queue must be able to access the data source as it needs to copy data. 
	# So it either can access the mount point directly or has ssh passwordless to access the data source. 

	if [ $IS_DM = "Y" ]; then
		if [ $DM_VERSION = "9.1" ]; then
			cd $LSF_TOP/9.1/install
			./patchinstall --silent -f $LSF_TOP/conf/lsf.conf /opt/dminstalldir/lsf9.1.3_linux2.6-glibc2.3-x86_64-242435.tar.Z
			cd /opt/dminstalldir/
			
			#For the DM installation package we only uncompress it once
			if [ $LSF_CLUSTER_NAME = "c1" ]; then
				tar -zxvf lsf9.1.3_data_mgr-linux-x64.tar.Z
			fi
			
			. $LSF_TOP/conf/profile.lsf
			cd /opt/dminstalldir/lsf9.1.3_data_mgr-linux-x64
			
			cp 9.1/linux2.6-glibc2.3-x86_64/etc/dmd $LSF_SERVERDIR/
			cp 9.1/linux2.6-glibc2.3-x86_64/bin/* $LSF_BINDIR/
			cp conf/TMPL.lsf.datamanager $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			chown lsfadmin $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			cp -R man/* $LSF_BINDIR/../../man/
			cp 1986-03.com.ibm_IBM_Platform_Data_Manager_for_LSF-9.1.3.swidtag $LSF_BINDIR/../../../properties/version

			# Install the latest DM patch 330371 
			cd $LSF_ENVDIR/../9.1/install
			./patchinstall --silent -f $LSF_ENVDIR/lsf.conf /opt/dminstalldir/lsf9.1.3_linux2.6-glibc2.3-x86_64-330371.tar.Z
		
			# Configure LSF and DM
			echo "LSF_DATA_HOSTS=${LSF_CLUSTER_NAME}-slave1-id$ID" >> $LSF_ENVDIR/lsf.conf
			echo "LSF_DATA_PORT=45780" >> $LSF_ENVDIR/lsf.conf

			mkdir -p /opt/$LSF_CLUSTER_NAME/dmsa

			dmconf=$LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			echo "Begin Parameters" >> $dmconf
			echo "ADMINS = lsfadmin" >> $dmconf
			echo "STAGING_AREA = /opt/$LSF_CLUSTER_NAME/dmsa" >> $dmconf
			echo "CACHE_INPUT_GRACE_PERIOD = 1440" >> $dmconf
			echo "CACHE_OUTPUT_GRACE_PERIOD = 180" >> $dmconf
			echo "CACHE_PERMISSIONS = user" >> $dmconf
			echo "QUERY_NTHREADS = 4" >> $dmconf
			echo "CACHE_ACCESSIBLE_FILES=Y" >> $dmconf
			echo "End Parameters" >> $dmconf
			
			# RemoteDataManagers
			
			if [ $LSF_CLUSTER_NAME = "c1" ]; then			
				echo "Begin RemoteDataManagers" >> $dmconf
				echo "CLUSTERNAME	SERVERS	PORT" >> $dmconf
				for((i=2;i<=$LSF_CLUSTER_NUM;i++)) #Cluster c1 is the submission cluster
				do
					echo "c$i	c$i-slave1-id$ID	45780" >> $dmconf
				done
			
				echo "End RemoteDataManagers" >> $dmconf
			fi
			
			tranq=$LSF_ENVDIR/lsbatch/$LSF_CLUSTER_NAME/configdir/lsb.queues
			echo -e "\nBegin Queue" >> $tranq
			echo "QUEUE_NAME = transfer" >> $tranq
			echo "DATA_TRANSFER = Y" >> $tranq
			echo "HOSTS = ${LSF_CLUSTER_NAME}-slave2-id$ID" >> $tranq
			echo "End Queue" >> $tranq

			echo "LSF_DATA_PORT=45780" >> lsf.conf


		elif [ $DM_VERSION= "10.1" ]; then
			echo "DM10.1..."
		fi
	fi
	
fi




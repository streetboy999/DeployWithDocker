#!/bin/bash

### Run in a docker container to install LSF ###

# Input Environment vars
# "EC_IP=$ecIP" "IS_LSFEXP=$isLSFExp" "DM_VERSION=$dmVersion" "IS_DM=$isDM" "LSF_VERSION=$lsfVersion" 
# "ID=$ID" "LSF_DOMAIN=$domain" "IS_MC=$isMC" "HOST_NUM=$HOST_NUM" "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" 
# "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" 
# "LSF_CLUSTER_NAME=$lsfClusterName" "LSF_MASTER_NAME=$lsfMasterName" "LSF_TOP=$lsfTop" "LSF_TAR_DIR=$lsfTarDir"

# Backup env vars because after sourcing LSF profile, all other entrypoint vars are empty
ismc=$IS_MC
lsmode=$LS_MODE
lsfclusternumber=$LSF_CLUSTER_NUM

LSFEXP_INSTALLDIR="/opt/lsfexpinstalldir"

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

# SS installation package was put into the same dir of LSF. Just change the installation expect script
# Just notice that for SS9.1.3, since there is no 9.1.3 package I just put 9.1.2 package there. But I have to change the name to 9.1.3 otherwise the installer cannot find the installation package. 
if [ $IS_SS="y" ]; then  
	/opt/ssinstall.exp $installFile
else
	/opt/install.exp $installFile
fi

# add ssh support by default
echo "LSF_RSH=ssh" >> $LSF_TOP/conf/lsf.conf

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
			
			# Install the folder enhancement project for DM9.1.3
			./patchinstall --silent -f $LSF_ENVDIR/lsf.conf /opt/dminstalldir/lsf9.1.3_data_mgr-linux-x64-456054.tar.Z
		
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


		elif [ $DM_VERSION = "10.1" ]; then
			echo "DM10.1..."
			cd $LSF_TOP/10.1/install
			#./patchinstall --silent -f $LSF_TOP/conf/lsf.conf /opt/dminstalldir/lsf9.1.3_linux2.6-glibc2.3-x86_64-242435.tar.Z
			cd /opt/dminstalldir/
			tar -zxvf lsf10.1_data_mgr-lnx26-x64.tar.Z
			. $LSF_TOP/conf/profile.lsf
			cd /opt/dminstalldir/lsf10.1_data_mgr-*
			
			cp 10.1/linux2.6-glibc2.3-*/etc/* $LSF_SERVERDIR
			cp 10.1/linux2.6-glibc2.3-*/bin/* $LSF_BINDIR
			cp conf/TMPL.lsf.datamanager $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			chown lsfadmin $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			cp -R man/* $LSF_BINDIR/../../man/
			cp ibm.com_IBM_Spectrum_LSF_Data_Manager-10.1.0.swidtag $LSF_BINDIR/../../../properties/version
			
			# Install DM spk6
			
			# Cannot use LSF_TOP any more after sourcing LSF profile. LSF_ENVDIR can be used instead.
			cd $LSF_ENVDIR/../10.1/install
			./patchinstall --silent -f $LSF_ENVDIR/lsf.conf /opt/dminstalldir/lsf10.1_data_mgr-lnx26-x64-492733.tar.Z
			
			
			
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
			
			# Install the folder enhancement project for DM9.1.3
			./patchinstall --silent -f $LSF_ENVDIR/lsf.conf /opt/dminstalldir/lsf9.1.3_data_mgr-linux-x64-456054.tar.Z		
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


		elif [ $DM_VERSION = "10.1" ]; then
			echo "DM10.1..."
			#cd $LSF_TOP/9.1/install
			#./patchinstall --silent -f $LSF_TOP/conf/lsf.conf /opt/dminstalldir/lsf9.1.3_linux2.6-glibc2.3-x86_64-242435.tar.Z
			cd /opt/dminstalldir/
			
			#For the DM installation package we only uncompress it once
			if [ $LSF_CLUSTER_NAME = "c1" ]; then
				tar -zxvf lsf10.1_data_mgr-lnx26-x64.tar.Z
			fi
			
			. $LSF_TOP/conf/profile.lsf
			cd /opt/dminstalldir/lsf10.1_data_mgr-*			
			
			cp 10.1/linux2.6-glibc2.3-*/etc/* $LSF_SERVERDIR
			cp 10.1/linux2.6-glibc2.3-*/bin/* $LSF_BINDIR
			cp conf/TMPL.lsf.datamanager $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			chown lsfadmin $LSF_ENVDIR/lsf.datamanager.$LSF_CLUSTER_NAME
			cp -R man/* $LSF_BINDIR/../../man/
			cp ibm.com_IBM_Spectrum_LSF_Data_Manager-10.1.0.swidtag $LSF_BINDIR/../../../properties/version			
			
			# Install DM spk6
			
			# Cannot use LSF_TOP any more after sourcing LSF profile. LSF_ENVDIR can be used instead.
			cd $LSF_ENVDIR/../10.1/install
			./patchinstall --silent -f $LSF_ENVDIR/lsf.conf /opt/dminstalldir/lsf10.1_data_mgr-lnx26-x64-492733.tar.Z
			
			
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

		fi
	fi
	
fi


# Install LSF Explorer Clients 
if [[ $IS_LSFEXP =~ ^y[0-1] ]]; then
	cd $LSFEXP_INSTALLDIR
	installFileName=`ls | grep node | grep gz`
	tar -zxvf $installFileName
	lsfExpClientInstallDir=`ls -F | grep '/$' | grep node`
	cd $lsfExpClientInstallDir
	echo "EXPLORER_NODE_TOP=/opt/ibm/$LSF_CLUSTER_NAME" >> install.config
	echo "JDBC_CONNECTION_URL=$EC_IP:9200" >> install.config
	echo "LSF_ENVDIR=$LSF_TOP/conf" >> install.config
	if [ $LSF_VERSION = "9.1" ]; then
		lsfVersion="9"
	elif [ $LSF_VERSION = "10.1" ]; then
		lsfVersion="10"
	fi
	echo "LSF_VERSION=$lsfVersion" >> install.config
	echo "EXPLORER_ADMIN=root" >> install.config
	
	echo "Y" | ./ExplorerNodeInstaller.sh  -silent -f ./install.config
	#Hack the issue that cannot find binary type (Due to Centos6.9, it cannot be recoganized to Linux2.6)
	sed -i 's/BINARY_TYPE=\"fail\"/BINARY_TYPE=linux2.6-glibc2.3-x86_64/g' /opt/ibm/$LSF_CLUSTER_NAME/lsfsuite/ext/perf/conf/profile.perf
	
	# Modify LSF configuration file lsb.params to make LSF Exp collect data 
	lsfParamfile=$LSF_TOP/conf/lsbatch/$LSF_CLUSTER_NAME/configdir/lsb.params
	paramArray=(
				ENABLE_EVENT_STREAM=Y
				"ALLOW_EVENT_TYPE=JOB_NEW JOB_FINISH JOB_FINISH2 JOB_STARTLIMIT JOB_STATUS2 JOB_PENDING_REASONS"
				INCLUDE_DETAIL_REASONS=y
				RUNTIME_LOG_INTERVAL=10
				"GROUP_PEND_JOBS_BY = QUEUE & USERNAME & USER_GROUPS & LICENSE_PROJECT"
				"PENDING_TIME_RANKING = short[1,20] medium[21,400] long[401,]"
	)
	
	length=${#paramArray[@]}
	sed -i 's/ENABLE_EVENT_STREAM/\#ENABLE_EVENT_STREAM/g' $lsfParamfile # By default this value is set to n. Comment it, otherwise the last value (n) will take effect. 

	for ((i=$length-1;i>=0;i--))
	do
        element=${paramArray[$i]}
        sed -i "/Begin Parameters/a ${element}" $lsfParamfile
	done
	
fi


# Install and configure License Scheduler

if [ $IS_LS = 'y' ]; then
    echo "Installing LS"
    cd /opt/lsinstalldir
    tar -zxvf *.tar.Z
    cd *x86_64
    echo 'SILENT_INSTALL="Y"' >> setup.config



    if test ! -z $LSF_TOP; then  # If LSF_TOP exists
        echo "LSF_TOP=$LSF_TOP"
        echo "Sourced LSF profile"
        . $LSF_TOP/conf/profile.lsf
    elif test ! -z $LSF_ENVDIR; then # If LSF_ENVDIR exists (it happens after installing DM)
        echo "LSF_ENVDIR=$LSF_ENVDIR"
        echo "Sourced LSF profile"
        . $LSF_ENVDIR/profile.lsf

    else
        echo "Error: Cannot find LSF_TOP or LSF_ENV. Exit"
        exit
    fi
    # Install LS silently
    ./setup
    cp /opt/lsinstalldir/*entitlement* $LSF_ENVDIR/ls.entitlement
    echo "LS installation is completed."

    # Configure LS
    hname=`hostname`
    echo "debug: hostname=`hostname`"
    lstoolsdir="/opt/lstoolsinstalldir/flexlm10.8"
    echo "hname=$hname"

    # Restore env vars
    IS_MC=$ismc
    LS_MODE=$lsmode
    LSF_CLUSTER_NUM=$lsfclusternumber

    echo -e "
    Restoring entrypoint env var
    IS_MC=$IS_MC
    LS_MODE=$LS_MODE
    LSF_CLUSTER_NUM=$LSF_CLUSTER_NUM
    "

    if [ $IS_MC = "Y" ]; then
        if [[ $hname =~ "c1-master" ]]; then # Master node in c1. Will configure lsf.licensescheduler
            mv $LSF_ENVDIR/lsf.licensescheduler $LSF_ENVDIR/lsf.licensescheduler.bak
            if [ $LS_MODE = "1" ]; then
                echo "MC, cluster mode"
                exec 6>&1
                exec 1>$LSF_ENVDIR/lsf.licensescheduler

                echo -e "Begin Parameters\nPORT = 9581\nHOSTS = $hname\nADMIN =  lsfadmin\nLM_STAT_INTERVAL=30\nLMSTAT_PATH = $lstoolsdir\nCLUSTER_MODE=y\nMERGE_BY_SERVICE_DOMAIN=Y\nLM_REMOVE_INTERVAL=0\nEnd Parameters"

                echo -e "\nBegin Clusters\nCLUSTERS"

                for((i=1;i<=$LSF_CLUSTER_NUM;i++))
                do
                echo "c$i"
                done
                echo "End Clusters"

                echo -e "\nBegin ServiceDomain\nNAME = SD1\nLIC_SERVERS = ((1880@$hname))\nEnd ServiceDomain"
                echo ""

                fstr="c1 1"
                for((i=2;i<=$LSF_CLUSTER_NUM;i++))
                do
                    fstr="$fstr c${i} 1"
                done

                for((i=1;i<=3;i++))
                do
                    echo "Begin Feature"
                    echo "NAME                  = f${i}0"
                    echo "LM_LICENSE_NAME       = LSAutoFeature_${i}0"
                    echo "CLUSTER_DISTRIBUTION  = SD1($fstr)"
                    echo "End Feature"
                    echo ""
                done

                exec 1>&6
                exec 6>&-

                echo "Configuration is done."

            elif [ $LS_MODE = "2" ]; then
                echo "MC, project mode"
            fi
        else # c2, c3 ...
            mv $LSF_ENVDIR/lsf.licensescheduler $LSF_ENVDIR/lsf.licensescheduler.bak
            ln -s /opt/cluster1/conf/lsf.licensescheduler $LSF_ENVDIR/lsf.licensescheduler
        fi
    elif [ $IS_MC = "N" ]; then
        if [ $LS_MODE = "1" ]; then
            echo "Single cluster, cluster mode"
        elif [ $LS_MODE = "2" ]; then
            echo "Single cluster, project mode"
        fi

    fi

    chown lsfadmin $LSF_ENVDIR/lsf.licensescheduler

fi



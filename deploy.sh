#!/bin/bash
### This script is to deploy the user's products with Docker ###

## Environment Variables ##
WELCOME="Welcome to use the automatic IBM Spectrum LSF deployment tool!\n" 
PRODUCTS_NAME=""
VERSION=""
LSF_TOP=""
LSF_MASTER_NAME="master"
CLUSTER_NAME=""
CLUSTER_NUM="1"
HOST_NUM=""
NFS="/opt"
IMAGE="ubuntu:17.04.v1"
INSTALL_PACKAGE_DIR="."
INSTALL_LOCK="$NFS.lockfile"

## Functions ##


# Initialization 
#
# Copy installation scripts, binaries, entitlement file etc 
# If all those files exit (check the same level dir by default) do nothing. 
# Otherwise copy relative files. cp for local and scp for remote. Put files at same dir. 

function funcInitial() {
	echo "Initial..."
	productName=$1
	version=$2
	installPackageDir="/Users/cwwu/docker/Project/P2-AutoInstall/Raw_Packages/LSF9.1.3/OriginalPackage"
	
	# Logic to judge from  where to copy installation packages

	cp -r $installPackageDir installdir
	echo "Installtion Pckages are copied to $(pwd)/installdir"
}



# NFS node creation 
#
# Create NFS container for files persistent. 
# Share the dir which a user specifies. 

function funcCreateNFS() {
	echo "Create NFS node..."
	docker run -v $NFS --name nfs ubuntu:17.04 echo "NFS node is created successfully!"
	docker cp $(pwd)/installdir nfs:$NFS
	docker cp $(pwd)/install.entrypoint.sh nfs:$NFS
	docker cp $(pwd)/install.exp nfs:$NFS
	docker cp $(pwd)/sshnopasswd nfs:$NFS
	docker cp $(pwd)/buildlsf.entrypoint.sh nfs:$NFS
	export SSH_AUTO="$(pwd)/sshnopasswd"
}



# Installation
#
# Install products. Support multiple products
# 1. Copy all files to NFS
# 2. Start installation container
# 3. Launch entrypoint script to install in the container
# 4. Exit after finishing installation

function funcInstall() {
	echo "Start Installation..."
	# Standard LSF
	lsfInstallScriptFile="$NFS/installdir/lsf9.1.3_lsfinstall_linux_x86_64.tar.Z"
	lsfInstallBinaryfile="$NFS/installdir/lsf9.1.3_linux2.6-glibc2.3-x86_64.tar.Z"
	lsfInstallEntitlementFile="$NFS/installdir/platform_lsf_adv_entitlement.dat"
	lsfTop="$NFS/cluster"
	lsfTarDir="$NFS/installdir"
	entryPointFile="$NFS/install.entrypoint.sh"
	lsfClusterName=$CLUSTER_NAME
	lsfMasterName="master"
	LSF_TOP=$lsfTop
	docker run -idt --volumes-from nfs --name Install -h $lsfMasterName --cap-add=SYS_PTRACE -e "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" -e "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" -e "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" -e "LSF_CLUSTER_NAME=$lsfClusterName" -e "LSF_MASTER_NAME=$lsfMasterName" -e "LSF_TOP=$lsfTop" -e "LSF_TAR_DIR=$lsfTarDir" --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
	
	# Block until the installation completes
	docker wait Install > /dev/null 2>$1
	echo "LSF Installation Completed!"
	rm -rf installdir

}

function funcInstallMC() {
	echo "Start MC Installation..."
	# Standard LSF
	lsfInstallScriptFile="$NFS/installdir/lsf9.1.3_lsfinstall_linux_x86_64.tar.Z"
	lsfInstallBinaryfile="$NFS/installdir/lsf9.1.3_linux2.6-glibc2.3-x86_64.tar.Z"
	lsfInstallEntitlementFile="$NFS/installdir/platform_lsf_adv_entitlement.dat"
	
	#Install LSF for each cluster
	for((i=1;i<=$CLUSTER_NUM;i++))
	do		
		lsfTop="$NFS/cluster$i"
		lsfTarDir="$NFS/installdir"
		entryPointFile="$NFS/install.entrypoint.sh"
		lsfClusterName=c$i
		lsfMasterName="c$i-master"
		LSF_TOP=$lsfTop
		docker run -idt --volumes-from nfs --name Install.$lsfClusterName -h $lsfMasterName --cap-add=SYS_PTRACE -e "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" -e "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" -e "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" -e "LSF_CLUSTER_NAME=$lsfClusterName" -e "LSF_MASTER_NAME=$lsfMasterName" -e "LSF_TOP=$lsfTop" -e "LSF_TAR_DIR=$lsfTarDir"  --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
		docker wait Install.$lsfClusterName > /dev/null 2>&1
		echo "LSF Installation Completed for cluster: $lsfClusterName!"
		rm -rf installdir
	done

}


# Create cluster nodes and start cluster 
#
# Start DNS container
# Start each cluster nodes (each node is a container)
# Create user accounts, prepare environment and start cluster with entrypoint file

function funcBuildCluster() {
	echo "Build Cluster..."
	domain=$CLUSTER_NAME.com
	echo "Starting DNS Server"
	docker run -d --name dns-server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
	echo "DNS server is started"

	dnsIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' dns-server`
	isMasterNode="N"
	isLastNode="N"
	
	# Provide hosts list for password-less ssh
	if [ -e $SSH_AUTO/hosts.$CLUSTER_NAME ];then
		rm $SSH_AUTO/hosts.$CLUSTER_NAME
		touch $SSH_AUTO/hosts.$CLUSTER_NAME
	else
		touch $SSH_AUTO/hosts.$CLUSTER_NAME

	fi

	# Build Cluster Nodes
	
	entrypointBuildLSF="$NFS/buildlsf.entrypoint.sh"
	for i in `seq 1 $HOST_NUM`;do
		j=$[$i-1]
		if [ $i -eq 1 ]; then
			isMasterNode="Y"
			hostName=$LSF_MASTER_NAME
		else 
			hostName="slave$j"

		fi
		if [ $i -eq $HOST_NUM ]; then
			isLastNode="Y"
		fi

		docker run -idt --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from nfs --cap-add=SYS_PTRACE -e "IS_MASTER_NODE=$isMasterNode" -e "IS_LAST_NODE=$isLastNode" -e "CLUSTER_NAME=$CLUSTER_NAME" -e "LSF_TOP=$LSF_TOP" -e "LOCK_FILE=$NFS/lockfile" -e "NO_GO=$NFS/nogo" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE > /dev/null 2>&1
		
		echo $hostName >> $SSH_AUTO/hosts.$CLUSTER_NAME
		echo "Created LSF HOST: $hostName"

		isMasterNode="N"
		isLastNode=="N" 
	done
	docker cp $SSH_AUTO/hosts.$CLUSTER_NAME nfs:$NFS/sshnopasswd
	rm $SSH_AUTO/hosts.$CLUSTER_NAME
}
	


function funcBuildClusterMC() {
	echo "Build MC Cluster..."
	domain="MC.com"
	echo "Starting DNS Server"
	docker run -d --name dns-server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
	echo "DNS server is started"

	dnsIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' dns-server`
	
	
	for((k=1;k<=$CLUSTER_NUM;k++))
	do
		isMasterNode="N"
		isLastNode="N"
		clusterName="c$k"
		lsfTop="$NFS/cluster$k"
		LSF_TOP=$lsfTop
		# Provide hosts list for password-less ssh
		if [ -e $SSH_AUTO/hosts.$clusterName ];then
			rm $SSH_AUTO/hosts.$clusterName
			touch $SSH_AUTO/hosts.$clusterName
		else
			touch $SSH_AUTO/hosts.$clusterName

		fi

		# Build Cluster Nodes
	
		entrypointBuildLSF="$NFS/buildlsf.entrypoint.sh"
		for((i=1;i<=$HOST_NUM;i++))
		do
			j=$[$i-1]
			if [ $i -eq 1 ]; then
				isMasterNode="Y"
				hostName="c$k-master"
			else 
				hostName="c$k-slave$j"

			fi
			if [ $i -eq $HOST_NUM ]; then
				isLastNode="Y"
			fi

			docker run -idt --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from nfs --cap-add=SYS_PTRACE -e "IS_MASTER_NODE=$isMasterNode" -e "IS_LAST_NODE=$isLastNode" -e "CLUSTER_NAME=$clusterName" -e "LSF_TOP=$LSF_TOP" -e "LOCK_FILE=$NFS/lockfile.$clusterName" -e "NO_GO=$NFS/nogo.$clusterName" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE 
		
			echo $hostName >> $SSH_AUTO/hosts.$clusterName
			echo "Created LSF HOST: $hostName for cluster: $clusterName"

			isMasterNode="N"
			isLastNode=="N"
		done
		docker cp $SSH_AUTO/hosts.$clusterName nfs:$NFS/sshnopasswd
		rm $SSH_AUTO/hosts.$clusterName
	done
}




# Export
# 
# Backup all files for migaration
# Export all backup data, variables etc. to a file
# tar all data into a file

function funcExport() {
	ehco "Exporting..."
}


# Import
#
# Restore backup files from a tar file
# Uncompress the backup files
# Rebuild the environmnet by invoking other functions

function funcImport() {
	echo "Importing..."
}

# Logging
#
# Generate standard logging entries for debugging and testing

function funcLog() {
	echo "Logging entries..."
}

# User interface
#
# This function is for user interaction. 
# It has two ways: 1. Interactive 2. CLI

function funcUserInteract() {
	echo "Start from here..."
	echo -e "	Welcome to use the automatic IBM Spectrum LSF deployment tool!\n\n"
	echo -e "What products do you want to deploy:"
	echo -e "1. LSF"
	echo -e "2. Multiple Cluster"
	echo -e "3. License Scheudler"
	echo -e "4. Data Manager"
	read -p "Your choice:(1)" choice
	choice=${choice:-1}
	echo -e "$choice\n"
	
	case $choice in 
		"1")
			echo "LSF"
			PRODUCTS_NAME="LSF"

			echo -e "Choose LSF version:\n"
			echo -e "1. LSF9.1.3\n"
			echo -e "2. LSF10.1\n"
			read -p "Input:(1)" version
			version=${version:-1}
			if [ $version = "1" ];then
				LSF_VERSION=9.1.3
			elif [ $version = "2" ];then
				LSF_VERSION=10.1
			else
				echo "Wrong Input. Exit!"
				exit
			fi
			read -p "Input Cluster Name:(mycluster)" clusterName
			clusterName=${clusterName:-"mycluster"}
			CLUSTER_NAME=$clusterName
			read -p "How many hosts do you want to create?(5)" hostNum
			hostNum=${hostNum:-5}
			HOST_NUM=$hostNum
			
			funcInitial $PRODUCTS_NAME $LSF_VERSION
			funcCreateNFS
			funcInstall $PRODUCTS_NAME $CLUSTER_NAME $CLUSTER_NUMBER $HOST_NUM
			funcBuildCluster

		;;
		
		"2")
			echo "Multiple Cluster"
			echo -e "Choose LSF version:\n"
			echo -e "1. LSF9.1.3\n"
			echo -e "2. LSF10.1\n"
			read -p "Input:(1)" version
			version=${version:-1}
			if [ $version = "1" ];then
				LSF_VERSION=9.1.3
			elif [ $version = "2" ];then
				LSF_VERSION=10.1
			else
				echo "Wrong Input. Exit!"
				exit
			fi

			read -p "How many clusters do you want to create?:(4)" cNum
			cNum=${cNum:-4}
			if [ $cNum -lt 2 ]; then
				echo -e "The smallest number of clusters is 2!\n"
				exit
			fi
			CLUSTER_NUM=$cNum
			read -p "How many nodes in each cluster?:(2)" hNum
			hNum=${hNum:-2}
			HOST_NUM=$hNum
			
			funcInitial $PRODUCTS_NAME $LSF_VERSION
			funcCreateNFS
			funcInstallMC
			funcBuildClusterMC



		;;
		
		"3")
			echo "License Scheduler"
		;;
		
		"4")
			echo "Data Manager"
		;;

		*)
			echo "Wrong Input. Exit!"
			exit
		;;
	







	esac












	
}

funcUserInteract




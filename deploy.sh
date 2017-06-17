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
IMAGE4SAS="ubuntu:17.04.v2"
INSTALL_PACKAGE_DIR="."
INSTALL_LOCK="$NFS.lockfile"

# You need to put the necessary LSF installation files in the direcotry below. The files include
# <lsf_version>_lsfinstall_linux_x86_64.tar.Z
# <lsf_version>_linux2.6-glibc2.3-x86_64.tar.Z
# entitlement file
INSTALL_PACKAGE_DIR_FOR_LSF913=""
INSTALL_PACKAGE_DIR_FOR_LSF101=""
INSTALL_PACKAGE_DIR_FOR_SAS_PSS91=""
INSTALL_PACKAGE_DIR_FOR_DM913=""


# LSF spk files directory
SPK_DIR_FOR_LSF913=""
SPK_DIR_FOR_LSF101=""

# The image file that you choose to create docker containers
IMAGE=""
IMAGE4SAS=""

# ContainerID file
CONFIGURE_LSF_FILE="./configure.lsf"
CONTAINER_ID_FILE="./container.id"
ID=1



## Functions ##

# ID and ID file to prevent two or more users run the tool in parallel
function ID++(){
   ((ID++))
   	echo $ID > $CONTAINER_ID_FILE
   	export ID
}


# Clean function
# Remove lock file if the tool exits
function funcClean() {
	echo -e "\nCleaning..."
	if [ -e $(pwd)/.lockfile ]; then
		rm $(pwd)/.lockfile
		if [ $? -eq 0 ]; then
			echo "Released lock file"
		fi
	fi
	if [ -L "installdir" ]; then
		unlink installdir
		echo "Unlinked installdir"
	fi
	
	if [ -L "dminstalldir" ]; then
		unlink dminstalldir
		echo "Unlinked dminstalldir"
	fi
	echo "Cleaning completed!"
}

# Customize the EXIT function and can define the user's own operations before exit
function EXIT() {
	funcClean
	#echo -e "Exit...\n"
	exit
}

# If the user press Ctrl+C, get the tool exited and clean up the lock file
function funcTrapInt
{
	echo -e "\nRecieve signal INT and quit!"
	EXIT
}


# Initialization 
#
# Copy installation scripts, binaries, entitlement file etc 
# If all those files exit (check the same level dir by default) do nothing. 
# Otherwise copy relative files. cp for local and scp for remote. Put files at same dir. 

function funcInitial() {
	echo "Initializing..."
	
	# Export all necessary environment variables and get the 
	. $CONFIGURE_LSF_FILE
	
	# Check if the ID file exists. If yes, get it and add 1. If not, set it to 1
	if [ -e $CONTAINER_ID_FILE ]; then
		ID=`cat $CONTAINER_ID_FILE`
		ID++
	else
		ID=0
		ID++
	fi	
	
	productName=$1
	version=$2

	case $version in 
			"9.1.3")

					installPackageDir=$INSTALL_PACKAGE_DIR_FOR_LSF913
	
					# Feed to patch installation function 
					LSF_PATCH_FILE=`ls $SPK_DIR_FOR_LSF913`
					LSF_PATCH_FILE="$SPK_DIR_FOR_LSF913/$LSF_PATCH_FILE"
					
					# Check if DM will be installed
					if [ $productName = "DM" ]; then
						installPackageDir4DM=$INSTALL_PACKAGE_DIR_FOR_DM913
					fi
			;;
			
			"10.1")
					installPackageDir=$INSTALL_PACKAGE_DIR_FOR_LSF101
					LSF_PATCH_FILE=`ls $SPK_DIR_FOR_LSF101`
					LSF_PATCH_FILE="$SPK_DIR_FOR_LSF101/$LSF_PATCH_FILE"
					
					# Check if DM will be installed
					if [ $productName = "DM" ]; then
						installPackageDir4DM=$INSTALL_PACKAGE_DIR_FOR_DM101
					fi
			;;
			
			*)
					echo "Wrong Version!"
					EXIT
			;;
	esac
	
	export LSF_PATCH_FILE #="/Users/cwwu/docker/Project/P2-AutoInstall/Raw_Packages/LSF9.1.3/SPK/spk8/lsf9.1.3_linux2.6-glibc2.3-x86_64-441747.tar.Z"
	
	# Logic to judge from  where to copy installation packages
	ln -s $installPackageDir installdir
	
	if [ $productName = "DM" ]; then
		echo "installPackageDir4DM=$installPackageDir4DM"
		ln -s $installPackageDir4DM dminstalldir
	fi
	echo -e "Initializing Completed!\n"
	#cp -r $installPackageDir installdir
	#echo -e "Installtion Packages are linked to $(pwd)/installdir\n"
}

function funcSASInitial() {
	echo "SAS Initializing..."
		# Export all necessary environment variables and get the 
	. $CONFIGURE_LSF_FILE
	
	# Check if the ID file exists. If yes, get it and add 1. If not, set it to 1
	if [ -e $CONTAINER_ID_FILE ]; then
		ID=`cat $CONTAINER_ID_FILE`
		ID++
		echo "ID=$ID"
	else
		ID=0
		ID++
		echo "ID=$ID"
	fi
	export SAS_INSTALL_PACK=$INSTALL_PACKAGE_DIR_FOR_SAS_PSS91 #"/Users/cwwu/docker/Project/P2-AutoInstall/Raw_Packages/PPM/sas_pss9.1"
}


# NFS node creation 
#
# Create NFS container for files persistent. 
# Share the dir which a user specifies. 

function funcCreateNFS() {
	echo "Creating NFS node..."
	export nfs="NFS-id$ID"
	docker run -v $NFS --name $nfs $IMAGE echo "NFS-id$ID" > /dev/null
	docker cp -L $(pwd)/installdir $nfs:$NFS
	if [ -L $(pwd)/dminstalldir ]; then
		docker cp -L $(pwd)/dminstalldir $nfs:$NFS
	fi
	docker cp $(pwd)/install.entrypoint.sh $nfs:$NFS
	docker cp $(pwd)/install.exp $nfs:$NFS
	docker cp $(pwd)/sshnopasswd $nfs:$NFS
	docker cp $(pwd)/buildlsf.entrypoint.sh $nfs:$NFS
	docker cp $(pwd)/patchinstall.entrypoint.sh $nfs:$NFS
	export SSH_AUTO="$(pwd)/sshnopasswd"
	echo -e "NFS node is created successfully!\n"
}

function funcSASCreateNFS() {
	echo "SAS Creating NFS node..."
	export nfs="NFS-id$ID"
	docker run -v $NFS --name $nfs $IMAGE4SAS echo "NFS-id$ID" > /dev/null
	docker cp $SAS_INSTALL_PACK $nfs:$NFS
	docker cp $(pwd)/sasinstall.entrypoint.sh $nfs:$NFS
	docker cp $(pwd)/sasinstall.exp $nfs:$NFS
	docker cp $(pwd)/sshnopasswd $nfs:$NFS
	docker cp $(pwd)/buildsas.entrypoint.sh $nfs:$NFS
	export SSH_AUTO="$(pwd)/sshnopasswd"
	echo -e "NFS node is created successfully!\n"
}


# Install LSF patch
#
# 	Input Paramasters: 
# 	$1 LSF version: 9.1 or 10.1
# 	$2 LSF patch file
# 	$3 LSF TOP directory
# 	$4 NFS directory
# 	$5 LSF Master Name
function funcPatch() {
	echo "Starting to apply a patch..."
	lsfVersion=$1
	lsfPatchFile=$2
	lsfTop=$3
	nfsDir=$4
	lsfMasterName=$5
	patchName="patch.tar.Z"
	entryPointFile="$nfsDir/patchinstall.entrypoint.sh"
	
	docker cp $lsfPatchFile $nfs:$nfsDir/$patchName
	
	PatchInstall="PatchInstall-id$ID"
	docker run -idt --volumes-from $nfs --name $PatchInstall -h $lsfMasterName -e "LSF_VERSION=$lsfVersion" -e "LSF_PATCH_FILE=$nfsDir/$patchName" -e "LSF_TOP=$lsfTop" -e "NFS=$nfsDir"  --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
	docker wait $PatchInstall > /dev/null 2>&1
	echo -e "Patch Installation Completed!\n"
	

}

# Installation
#
# Install products. Support multiple products
# 1. Copy all files to NFS
# 2. Start installation container
# 3. Launch entrypoint script to install in the container
# 4. Exit after finishing installation
# Input Parameters:
# needInstallPatch (y or n) 
# lsfVersion (9.1 or 10.1)
# isDM (Y or N)
# dmVersion (9.1 or 10.1)

function funcInstall() {
	echo "Starting Installation..."
	# Standard LSF
	needInstallPatch=$1
	lsfVersion=$2
	isDM=$3
	dmVersion=$4
	
	case $lsfVersion in 
			"9.1")
					
	
					lsfInstallScriptFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep install`
					lsfInstallScriptFile="$NFS/installdir/$lsfInstallScriptFile"
	
					lsfInstallBinaryfile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep glibc`
					lsfInstallBinaryfile="NFS/installdir/$lsfInstallBinaryfile"
	
					lsfInstallEntitlementFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep entitlement`
					lsfInstallEntitlementFile="$NFS/installdir/$lsfInstallEntitlementFile"
			;;
			"10.1")
					lsfInstallScriptFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep install`
					lsfInstallScriptFile="$NFS/installdir/$lsfInstallScriptFile"
	
					lsfInstallBinaryfile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep glibc`
					lsfInstallBinaryfile="NFS/installdir/$lsfInstallBinaryfile"
	
					lsfInstallEntitlementFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep entitlement`
					lsfInstallEntitlementFile="$NFS/installdir/$lsfInstallEntitlementFile"					
			;;
			*)
					echo "Wrong version!"
					EXIT
			;;
	esac
		
	#lsfInstallScriptFile="$NFS/installdir/lsf9.1.3_lsfinstall_linux_x86_64.tar.Z"
	#lsfInstallBinaryfile="$NFS/installdir/lsf9.1.3_linux2.6-glibc2.3-x86_64.tar.Z"
	#lsfInstallEntitlementFile="$NFS/installdir/platform_lsf_adv_entitlement.dat"
	
	
	
	lsfTop="$NFS/cluster"
	lsfTarDir="$NFS/installdir"
	entryPointFile="$NFS/install.entrypoint.sh"
	lsfClusterName=$CLUSTER_NAME
	export lsfMasterName="master-id$ID"
	LSF_TOP=$lsfTop
	isMC="N"
	domain="$CLUSTER_NAME$ID.com"
	Install="Install-id$ID"
	docker run -idt --volumes-from $nfs --name $Install -h $lsfMasterName --cap-add=SYS_PTRACE -e "DM_VERSION=$dmVersion" -e "IS_DM=$isDM" -e "LSF_VERSION=$lsfVersion" -e "ID=$ID" -e "LSF_DOMAIN=$domain" -e "IS_MC=$isMC" -e "HOST_NUM=$HOST_NUM" -e "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" -e "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" -e "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" -e "LSF_CLUSTER_NAME=$lsfClusterName" -e "LSF_MASTER_NAME=$lsfMasterName" -e "LSF_TOP=$lsfTop" -e "LSF_TAR_DIR=$lsfTarDir" --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
	
	# Block until the installation completes
	docker wait $Install > /dev/null 2>&1
	echo -e "LSF Installation Completed!\n"
	#rm -rf installdir
	unlink installdir
	

	if [ $needInstallPatch = "y" ]; then
		# Get the patch file from the env var of initialization 
		lsfPatchFile=$LSF_PATCH_FILE
		funcPatch $lsfVersion $lsfPatchFile $lsfTop $NFS $lsfMasterName
	fi

}

function funcInstallMC() {
	echo "Starting MC Installation..."
	# Standard LSF
	#lsfInstallScriptFile="$NFS/installdir/lsf9.1.3_lsfinstall_linux_x86_64.tar.Z"
	#lsfInstallBinaryfile="$NFS/installdir/lsf9.1.3_linux2.6-glibc2.3-x86_64.tar.Z"
	#lsfInstallEntitlementFile="$NFS/installdir/platform_lsf_adv_entitlement.dat"
	
	needInstallPatch=$1
	lsfVersion=$2
	
	case $lsfVersion in 
			"9.1")
					
	
					lsfInstallScriptFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep install`
					lsfInstallScriptFile="$NFS/installdir/$lsfInstallScriptFile"
	
					lsfInstallBinaryfile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep glibc`
					lsfInstallBinaryfile="NFS/installdir/$lsfInstallBinaryfile"
	
					lsfInstallEntitlementFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep entitlement`
					lsfInstallEntitlementFile="$NFS/installdir/$lsfInstallEntitlementFile"
			;;
			"10.1")
					lsfInstallScriptFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep install`
					lsfInstallScriptFile="$NFS/installdir/$lsfInstallScriptFile"
	
					lsfInstallBinaryfile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep glibc`
					lsfInstallBinaryfile="NFS/installdir/$lsfInstallBinaryfile"
	
					lsfInstallEntitlementFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep entitlement`
					lsfInstallEntitlementFile="$NFS/installdir/$lsfInstallEntitlementFile"					
			;;
			*)
					echo "Wrong version!"
					EXIT
			;;
	esac
	
	domain="MC${ID}.com"
		
	#Install LSF for each cluster
	for((i=1;i<=$CLUSTER_NUM;i++))
	do		
		lsfTop="$NFS/cluster$i"
		lsfTarDir="$NFS/installdir"
		entryPointFile="$NFS/install.entrypoint.sh"
		lsfClusterName=c$i
		lsfMasterName="c$i-master-id$ID"
		LSF_TOP=$lsfTop
		isMC="Y"
		Install="Install.${lsfClusterName}-id$ID"
		docker run -idt --volumes-from $nfs --name $Install -h $lsfMasterName --cap-add=SYS_PTRACE -e "LSF_VERSION=$lsfVersion" -e "ID=$ID" -e "LSF_DOMAIN=$domain" -e "IS_MC=$isMC" -e "HOST_NUM=$HOST_NUM" -e "LSF_CLUSTER_NUM=$CLUSTER_NUM" -e "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" -e "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" -e "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" -e "LSF_CLUSTER_NAME=$lsfClusterName" -e "LSF_MASTER_NAME=$lsfMasterName" -e "LSF_TOP=$lsfTop" -e "LSF_TAR_DIR=$lsfTarDir"  --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
		docker wait $Install > /dev/null 2>&1
		echo "LSF Installation Completed for cluster: $lsfClusterName!"
		
		#Install patch for each cluster
		if [ $needInstallPatch = "y" ]; then
			# Get the patch file from the env var of initialization 
			lsfPatchFile=$LSF_PATCH_FILE
			funcPatch $lsfVersion $lsfPatchFile $lsfTop $NFS $lsfMasterName
		fi
	done
	unlink installdir
	echo -e "\n"

}

function funcSASInstall() {
	echo "Starting SAS Installation..."
	hostNum=$1
	sasInstallPack="$NFS/sas_pss9.1/pm9.1.3.0_sas_lnx26-lib23-x64.tar"
	sasInstallEntitlementFile="$NFS/sas_pss9.1/platform_lsf_adv_entitlement.dat"
	sasInstallDir="$NFS/pm9.1.3.0_sas_pinstall"
	isSAS="Y"
	entryPointFile="$NFS/sasinstall.entrypoint.sh"
	export LSF_DOMAIN="sas.com"
	export JS_TOP="$NFS/sas/pm9.1.3"
	JS_HOST=master
	JS_ADMINS=lsfadmin
	LSF_INSTALL="true"
	export LSF_TOP="$NFS/sas/lsf9.1.3"
	export LSF_CLUSTER_NAME="sas"
	LSF_MASTER_LIST="master"
	#Input Env Vars: SAS_INSTALL_PACK SAS_INSTALL_ENTITLEMENT_FILE SAS_INSTALL_DIR IS_SAS
	docker run -idt --volumes-from $nfs --name Install -h $JS_HOST --cap-add=SYS_PTRACE -e "LSF_DOMAIN=$LSF_DOMAIN" -e "HOST_NUM=$hostNum" -e "NFS=$NFS" -e "SAS_INSTALL_PACK=$sasInstallPack" -e "SAS_INSTALL_ENTITLEMENT_FILE=$sasInstallEntitlementFile" -e "SAS_INSTALL_DIR=$sasInstallDir" -e "IS_SAS=$isSAS" -e "JS_TOP=$JS_TOP" -e "JS_HOST=$JS_HOST" -e "JS_ADMINS=$JS_ADMINS" -e "LSF_INSTALL=$LSF_INSTALL" -e "LSF_TOP=$LSF_TOP" -e "LSF_CLUSTER_NAME=$LSF_CLUSTER_NAME" -e "LSF_MASTER_LIST=$LSF_MASTER_LIST" --entrypoint $entryPointFile $IMAGE4SAS >/dev/null 2>&1
	docker wait Install > /dev/null 2>&1
	echo -e "SAS (LSF+PM) Installation completed!\n"

	
}


# Create cluster nodes and start cluster 
#
# Start DNS container
# Start each cluster nodes (each node is a container)
# Create user accounts, prepare environment and start cluster with entrypoint file

function funcBuildCluster() {
	echo "Building Cluster..."
	domain="${CLUSTER_NAME}${ID}.com"
	#sleep 10
	echo "Starting DNS Server"
	dns_server="dns-server-id$ID"
	docker run -d --name $dns_server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
	echo "DNS server is started"

	dnsIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' $dns_server`
	
	# Provide hosts list for password-less ssh
	if [ -e $SSH_AUTO/hosts.$CLUSTER_NAME ];then
		rm $SSH_AUTO/hosts.$CLUSTER_NAME
		touch $SSH_AUTO/hosts.$CLUSTER_NAME
	else
		touch $SSH_AUTO/hosts.$CLUSTER_NAME

	fi

	# Build Cluster Nodes
	
	entrypointBuildLSF="$NFS/buildlsf.entrypoint.sh"
	for((i=1;i<=$HOST_NUM;i++)); do
		j=$[$i-1]
		if [ $i -eq 1 ]; then
			hostName=$lsfMasterName
		else 
			hostName="slave${j}-id$ID"

		fi
		#hostName="${hostName}-id$ID"
		docker run -idt --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from $nfs --cap-add=SYS_PTRACE -e "ID=$ID" -e "CLUSTER_NAME=$CLUSTER_NAME" -e "LSF_TOP=$LSF_TOP" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE > /dev/null 2>&1
		
		echo $hostName >> $SSH_AUTO/hosts.$CLUSTER_NAME
		echo "Created LSF HOST: $hostName"

	done
	
	# Copy hosts file to shared NFS which can be accessed by each container
	# The file is to feed ssh passwd-less function by getting all container host names
	docker cp $SSH_AUTO/hosts.$CLUSTER_NAME $nfs:$NFS/sshnopasswd
	
	# Start LSF in each container by sending signal SIGUSR1
	for i in `cat $SSH_AUTO/hosts.$CLUSTER_NAME`; do
		docker kill -s SIGUSR1 $i > /dev/null 2>&1
	done
	
	rm $SSH_AUTO/hosts.$CLUSTER_NAME
}
	


function funcBuildClusterMC() {
	echo "Building MC Cluster..."
	domain="MC${ID}.com"
	echo "Starting DNS Server"
	dns_server="dns-server-id$ID"
	docker run -d --name $dns_server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
	echo "DNS server is started"

	dnsIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' $dns_server`
	
	
	hostList=""
	
	for((k=1;k<=$CLUSTER_NUM;k++))
	do
		
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
		#Record All host names and feed to docker kill -s SIGUSR1
		for((i=1;i<=$HOST_NUM;i++))
		do
			j=$[$i-1]
			if [ $i -eq 1 ]; then
				hostName="c$k-master"
			else 
				hostName="c$k-slave$j"

			fi
			hostName="${hostName}-id$ID"
			hostList="$hostList $hostName"
			docker run -idt --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from $nfs --cap-add=SYS_PTRACE -e "CLUSTER_NAME=$clusterName" -e "LSF_TOP=$LSF_TOP" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE > /dev/null 2>&1
		
			echo $hostName >> $SSH_AUTO/hosts.$clusterName
			echo "Created LSF HOST: $hostName for cluster: $clusterName"

		done
		docker cp $SSH_AUTO/hosts.$clusterName $nfs:$NFS/sshnopasswd
		rm $SSH_AUTO/hosts.$clusterName
	done
	
	# Start each MC node

	for i in $hostList
	do
		docker kill -s SIGUSR1 $i > /dev/null 2>&1
	done
}


function funcSASBuild() {
	echo "Building SAS Cluster..."
	domain=$LSF_DOMAIN
	echo "Starting DNS Server"
	docker run -d --name dns-server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
	echo "DNS server is started"

	dnsIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' dns-server`
	
	hostList=""
	clusterName=$LSF_CLUSTER_NAME
	entrypointBuildSAS="$NFS/buildsas.entrypoint.sh"
	echo "Open XQuartz"
	open -a XQuartz
	ip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
	xhost + $ip 
	hostNum=$1
	for((i=1;i<=hostNum;i++))
	do
		j=$[$i-1]
		if [ $i -eq 1 ]; then
			hostName="master"
			IS_JS_MASTER="Y"			
		else 
			hostName="slave$j"
			IS_JS_MASTER="N"
		fi
		hostList="$hostList $hostName"
		docker run -idt --name $hostName -h $hostName --dns $dnsIP --dns-search $domain --volumes-from $nfs --cap-add=SYS_PTRACE -e DISPLAY=$ip:0 -e "CLUSTER_NAME=$clusterName" -e "LSF_TOP=$LSF_TOP" -e "JS_TOP=$JS_TOP" -e "IS_JS_MASTER=$IS_JS_MASTER" -v /tmp/.X11-unix:/tmp/.X11-unix --entrypoint $entrypointBuildSAS $IMAGE4SAS > /dev/null 2>&1
		
		echo $hostName >> $SSH_AUTO/hosts.$clusterName
		echo "Created LSF HOST: $hostName"		
	done
	docker cp $SSH_AUTO/hosts.$clusterName $nfs:$NFS/sshnopasswd
	# Start SAS cluster
	for i in $hostList
	do
		docker kill -s SIGUSR1 $i > /dev/null 2>&1
	done	
	rm $SSH_AUTO/hosts.$clusterName	

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
	echo -e "	Welcome to use the automatic IBM Spectrum products deployment tool!\n\n"
	echo -e "What products do you want to deploy:"
	echo -e "1. LSF"
	echo -e "2. Multiple Cluster"
	echo -e "3. SAS (LSF+PPM)"
	echo -e "4. Data Manager"
	#echo -e "5. License Scheudler"
	read -p "Your choice:(1)" choice
	choice=${choice:-1}
	echo -e "$choice"
	
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
				# To specify $LSF_TOP/<version>/
				lsfVersion=9.1
			elif [ $version = "2" ];then
				LSF_VERSION=10.1
				# To specify $LSF_TOP/<version>/
				lsfVersion=10.1
			else
				echo "Wrong Input. Exit!"
				EXIT
			fi
			read -p "Input Cluster Name:(mycluster)" clusterName
			clusterName=${clusterName:-"mycluster"}
			CLUSTER_NAME=$clusterName
			read -p "How many hosts do you want to create?(5)" hostNum
			hostNum=${hostNum:-5}
			HOST_NUM=$hostNum
			
			read -p "Do you want to install the latest patch?(y/n)(n)" needInstallPatch
			needInstallPatch=${needInstallPatch:-"n"}
			
			funcInitial $PRODUCTS_NAME $LSF_VERSION
			funcCreateNFS
			#funcInstall $PRODUCTS_NAME $CLUSTER_NAME $CLUSTER_NUMBER $HOST_NUM
			funcInstall $needInstallPatch $lsfVersion
			funcBuildCluster

		;;
		
		"2")
			echo "Multiple Cluster"
			PRODUCTS_NAME="MC"
			echo -e "Choose LSF version:\n"
			echo -e "1. LSF9.1.3\n"
			echo -e "2. LSF10.1\n"
			read -p "Input:(1)" version
			version=${version:-1}
			if [ $version = "1" ];then
				LSF_VERSION=9.1.3
				lsfVersion=9.1
			elif [ $version = "2" ];then
				LSF_VERSION=10.1
				lsfVersion=10.1
			else
				echo "Wrong Input. Exit!"
				EXIT
			fi

			read -p "How many clusters do you want to create?:(4)" cNum
			cNum=${cNum:-4}
			if [ $cNum -lt 2 ]; then
				echo -e "The smallest number of clusters is 2!\n"
				EXIT
			fi
			CLUSTER_NUM=$cNum
			read -p "How many nodes in each cluster?:(2)" hNum
			hNum=${hNum:-2}
			HOST_NUM=$hNum
			
			read -p "Do you want to install the latest patch?(y/n)(n)" needInstallPatch
			needInstallPatch=${needInstallPatch:-"n"}
			funcInitial $PRODUCTS_NAME $LSF_VERSION
			funcCreateNFS
			funcInstallMC $needInstallPatch $lsfVersion
			funcBuildClusterMC



		;;
		
		"5")
			echo "License Scheduler"
		;;
		
		"4")
			echo "Data Manager"
			
			PRODUCTS_NAME="DM"
			isDM="Y"

			echo -e "Choose Data Manager version:\n"
			echo -e "1. LSF9.1.3 + DM9.1.3\n"
			#echo -e "2. LSF10.1 + DM10.1\n"
			read -p "Input:(1)" version
			version=${version:-1}
			if [ $version = "1" ];then
				LSF_VERSION=9.1.3
				# To specify $LSF_TOP/<version>/
				lsfVersion=9.1
				dmVersion=9.1
			elif [ $version = "2" ];then
				LSF_VERSION=10.1
				# To specify $LSF_TOP/<version>/
				lsfVersion=10.1
				dmVersion=10.1
			else
				echo "Wrong Input. Exit!"
				EXIT
			fi
			read -p "Input Cluster Name:(mycluster)" clusterName
			clusterName=${clusterName:-"mycluster"}
			CLUSTER_NAME=$clusterName
			read -p "How many hosts do you want to create?(5)" hostNum
			hostNum=${hostNum:-5}
			HOST_NUM=$hostNum
			if [ $hostNum -lt 3 ]; then
				echo -e "DM cluster has 3 hosts at least. Exit..."
				EXIT
			fi
			
			read -p "Do you want to install the latest patch?(y/n)(n)" needInstallPatch
			needInstallPatch=${needInstallPatch:-"n"}
			
			funcInitial $PRODUCTS_NAME $LSF_VERSION
			funcCreateNFS
			#funcInstall $PRODUCTS_NAME $CLUSTER_NAME $CLUSTER_NUMBER $HOST_NUM
			funcInstall $needInstallPatch $lsfVersion $isDM $dmVersion
			funcBuildCluster
			
		;;
		
		"3")
			read -p "How many hosts do you want to create?(2)" hostNum
			hostNum=${hostNum:-2}
			
			funcSASInitial
			funcSASCreateNFS
			funcSASInstall $hostNum
			funcSASBuild $hostNum
		;;

		*)
			echo "Wrong Input. Exit!"
			EXIT
		;;



	esac
	
}

trap funcTrapInt SIGINT

while [ true ];do
	if [ -e ./.lockfile ];then
		echo "Someone is running the tool in parallel. Please wait..."
		sleep 10		
	else
		touch ./.lockfile	
		break
	fi
done

funcUserInteract
funcClean




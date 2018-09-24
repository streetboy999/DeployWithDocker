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
INSTALL_PACKAGE_DIR_FOR_SAS_PSS81=""
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
ID=0

# Elastic Search Server IP Address
EC_IP="0.0.0.0"

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
	currentUser="`whoami`"
	lockOwner="`ls -la | grep .lockfile | awk '{print $3}'`"
	if [ -e $(pwd)/.lockfile ]; then
		if [ $currentUser = $lockOwner ]; then
			rm $(pwd)/.lockfile
			
			if [ $? -eq 0 ]; then
				echo "Released lock file"
			fi
		else
			echo "Cleaning completed!"
			exit
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
	
	if [ -L "lsfexpinstalldir" ]; then
		unlink lsfexpinstalldir
		echo "Unlinked lsfexpinstalldir"
	fi

	user=`whoami`
	if [ -e $(pwd)/user_id.track ]; then
		echo "`date`" >> $(pwd)/user_id.track
    	echo "User: $user ID: id$ID" >> $(pwd)/user_id.track
    	echo "-----------------------" >> $(pwd)/user_id.track

	else
		touch $(pwd)/user_id.track
		chmod 777 $(pwd)/user_id.track
		echo "`date`" >> $(pwd)/user_id.track
    	echo "User: $user ID: id$ID" >> $(pwd)/user_id.track
    	echo "-----------------------" >> $(pwd)/user_id.track
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
	isLSFExp=$3 # If LSF Explorer will be installed
	#isLSFExp="y"

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
	
	installPackage4LSFEXP=$INSTALL_PACKAGE_DIR_FOR_LSF_EXPLORER
	
	# Logic to judge from  where to copy installation packages
	ln -s $installPackageDir installdir
	
	if [ $productName = "DM" ]; then
		ln -s $installPackageDir4DM dminstalldir
	fi
	
	
	# Only if the user requests to deploy LSF Explorer (Either server or client) does it copy installation packages to container.
	if [[ $isLSFExp =~ ^y[0-1] ]]; then
		ln -s $installPackage4LSFEXP lsfexpinstalldir
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
	else
		ID=0
		ID++
	fi
	sasVersion=$1
	if [ $sasVersion = "pss91" ]; then
		export SAS_INSTALL_PACK=$INSTALL_PACKAGE_DIR_FOR_SAS_PSS91 #"/Users/cwwu/docker/Project/P2-AutoInstall/Raw_Packages/PPM/sas_pss9.1"
	elif [ $sasVersion = "pss81" ]; then
		export SAS_INSTALL_PACK=$INSTALL_PACKAGE_DIR_FOR_SAS_PSS81
	fi
}


# NFS node creation 
#
# Create NFS container for files persistent. 
# Share the dir which a user specifies. 

function funcCreateNFS() {
	echo "Creating NFS node..."
	export nfs="NFS-id$ID"
	docker run --privileged=true -v $NFS --name $nfs $IMAGE echo "NFS-id$ID" > /dev/null
	docker cp -L $(pwd)/installdir $nfs:$NFS
	if [ -L $(pwd)/dminstalldir ]; then
		docker cp -L $(pwd)/dminstalldir $nfs:$NFS
	fi
	
	if [ -L $(pwd)/lsfexpinstalldir ]; then
		docker cp -L $(pwd)/lsfexpinstalldir $nfs:$NFS
		docker cp $(pwd)/installlsfexpserver.entrypoint.sh $nfs:$NFS
	fi
	
	docker cp $(pwd)/install.entrypoint.sh $nfs:$NFS
	docker cp $(pwd)/install.exp $nfs:$NFS
	docker cp $(pwd)/ssinstall.exp $nfs:$NFS
	docker cp $(pwd)/sshnopasswd $nfs:$NFS
	docker cp $(pwd)/buildlsf.entrypoint.sh $nfs:$NFS
	docker cp $(pwd)/patchinstall.entrypoint.sh $nfs:$NFS

	export SSH_AUTO="$(pwd)/sshnopasswd"
	echo -e "NFS node is created successfully!\n"
}

function funcSASCreateNFS() {
	echo "SAS Creating NFS node..."
	export nfs="NFS-id$ID"
	export SAS_INSTALL_DIR="$NFS/sasinstalldir"
	docker run --privileged=true -v $NFS --name $nfs $IMAGE4SAS echo "NFS-id$ID" > /dev/null
	docker cp $SAS_INSTALL_PACK $nfs:$SAS_INSTALL_DIR
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
	docker run --privileged=true -idt --volumes-from $nfs --name $PatchInstall -h $lsfMasterName -e "LSF_VERSION=$lsfVersion" -e "LSF_PATCH_FILE=$nfsDir/$patchName" -e "LSF_TOP=$lsfTop" -e "NFS=$nfsDir"  --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
	docker wait $PatchInstall > /dev/null 2>&1
	echo -e "Patch Installation Completed!\n"
	

}


# LSF Explorer Server (elasticsearch) Installation and Startup

# isLSFExp isLSFExp (y1 - Need to install Elastic Search Sever and Client, y0 - Need to install only Elastic Search Client or n - nothing to do)

function funcLSFExpServerSetup() {
	isLSFExp=$1
	if test -z "$isLSFExp"; then
		echo -e "Input parameter error. Exit..."
		EXIT
	fi
	
	if [ $isLSFExp = "y1" ]; then
	
		echo -e "No Elastic Search Server is running. Will Install a new one...\n"
		echo "Starting LSF Explorer Server (Elastic Search Server) Installation..."
		EcPackage=`ls $INSTALL_PACKAGE_DIR_FOR_LSF_EXPLORER | grep server`
		EcPackage="$NFS/lsfexpinstalldir/$EcPackage" #Elasticsearch server installation file
		entryPointFile="$NFS/installlsfexpserver.entrypoint.sh"
		# --previleged is necessary as Elastic Search needs to modify system settings like vm.max_map_count
		lsof -i :8080 > /dev/null
		
		#8080 is occupied
		if [ $? = "0" ]; then
			webPort="8080"
			echo "Port 8080 is occupied by the following process(es). Please Check. Exit from the tool."
			lsof -i :$webPort
			EXIT
		else
			webPort="8080:8080"
		fi
		docker run --privileged -idt -p $webPort -p 9200:9200 -p 5000:5000 --name elasticsearch -h elasticsearch --volumes-from $nfs --cap-add=SYS_PTRACE -e "ECPACKAGE=$EcPackage" --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
		export WEBPORT=`docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' elasticsearch | awk '{print $6}'`
		# This is to prevent race condition. Elastic search has not started up yet while LSF nodes are all up. 
		while [ true ];
		do
  		  docker logs elasticsearch | grep STARTED >> /dev/null
  		  if [ $? = "1" ]; then # WEBGUI Service is not started yet
  		  		sleep 1
  		  else
  		  		break
  		  fi
		done
		export EC_IP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' elasticsearch` 
		echo -e "LSF Explorer Server (Elastic Search Sever) Installation completed!\n"
	elif [ $isLSFExp = "y0" ]; then
		export EC_IP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' elasticsearch`
		echo -e "An Elastic Search Sever is already running! All clients will connect to it.\n"
	fi
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
# isLSFExp (y1 - Need to install Elastic Search Sever and Client, y0 - Need to install only Elastic Search Client or n - nothing to do)
# ecIP - Elastic Search IP address
# isSS - If install Session Scheduler
function funcInstall() {
	echo "Starting LSF Cluster Installation..."
	# Standard LSF
	needInstallPatch=$1
	lsfVersion=$2
	isDM=$3
	dmVersion=$4
	isLSFExp=$5
	ecIP=$6
	isSS=$7
	

	
	case $lsfVersion in 
			"9.1")
					
	
					lsfInstallScriptFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep install`
					lsfInstallScriptFile="$NFS/installdir/$lsfInstallScriptFile"
	
					lsfInstallBinaryfile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep glibc`
					lsfInstallBinaryfile="$NFS/installdir/$lsfInstallBinaryfile"
	
					lsfInstallEntitlementFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF913 | grep entitlement`
					lsfInstallEntitlementFile="$NFS/installdir/$lsfInstallEntitlementFile"
			;;
			"10.1")
					lsfInstallScriptFile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep install`
					lsfInstallScriptFile="$NFS/installdir/$lsfInstallScriptFile"
	
					lsfInstallBinaryfile=`ls $INSTALL_PACKAGE_DIR_FOR_LSF101 | grep glibc`
					lsfInstallBinaryfile="$NFS/installdir/$lsfInstallBinaryfile"
	
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
	lsfClusterName="$CLUSTER_NAME"
	export lsfMasterName="master-id$ID"
	LSF_TOP=$lsfTop
	isMC="N"
	domain="$CLUSTER_NAME$ID.com"
	Install="Install-id$ID"
	docker run --privileged=true -idt --volumes-from $nfs --name $Install -h $lsfMasterName --cap-add=SYS_PTRACE -e "IS_SS=$isSS" -e "EC_IP=$ecIP" -e "IS_LSFEXP=$isLSFExp" -e "DM_VERSION=$dmVersion" -e "IS_DM=$isDM" -e "LSF_VERSION=$lsfVersion" -e "ID=$ID" -e "LSF_DOMAIN=$domain" -e "IS_MC=$isMC" -e "HOST_NUM=$HOST_NUM" -e "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" -e "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" -e "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" -e "LSF_CLUSTER_NAME=$lsfClusterName" -e "LSF_MASTER_NAME=$lsfMasterName" -e "LSF_TOP=$lsfTop" -e "LSF_TAR_DIR=$lsfTarDir" --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
	
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


##	Params
#	needInstallPatch=$1
#	lsfVersion=$2
#	isDM=$3
#	dmVersion=$4
#	isLSFExp=$5
#	ecIP=$6
function funcInstallMC() {
	echo "Starting MC Installation..."
	# Standard LSF
	#lsfInstallScriptFile="$NFS/installdir/lsf9.1.3_lsfinstall_linux_x86_64.tar.Z"
	#lsfInstallBinaryfile="$NFS/installdir/lsf9.1.3_linux2.6-glibc2.3-x86_64.tar.Z"
	#lsfInstallEntitlementFile="$NFS/installdir/platform_lsf_adv_entitlement.dat"
	
	needInstallPatch=$1
	lsfVersion=$2
	isDM=$3
	dmVersion=$4
	isLSFExp=$5
	ecIP=$6
	
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
	isSubCluster="N" # If the cluster is submission cluster, it needs to configure remote DM
	for((i=1;i<=$CLUSTER_NUM;i++))
	do	
		if [ $i = "1" ]; then
			isSubCluster="Y"
		else
			isSubCluster="N"
		fi	
		lsfTop="$NFS/cluster$i"
		lsfTarDir="$NFS/installdir"
		entryPointFile="$NFS/install.entrypoint.sh"
		lsfClusterName=c$i
		lsfMasterName="c$i-master-id$ID"
		LSF_TOP=$lsfTop
		isMC="Y"
		Install="Install.${lsfClusterName}-id$ID"
		docker run --privileged=true -idt --volumes-from $nfs --name $Install -h $lsfMasterName --cap-add=SYS_PTRACE -e "EC_IP=$ecIP" -e "IS_LSFEXP=$isLSFExp" -e "IS_SUBCLUSTER=$isSubCluster" -e "DM_VERSION=$dmVersion" -e "IS_DM=$isDM" -e "LSF_VERSION=$lsfVersion" -e "ID=$ID" -e "LSF_DOMAIN=$domain" -e "IS_MC=$isMC" -e "HOST_NUM=$HOST_NUM" -e "LSF_CLUSTER_NUM=$CLUSTER_NUM" -e "LSF_INSTALL_SCRIPT_FILE=$lsfInstallScriptFile" -e "LSF_INSTALL_BINARY_FILE=$lsfInstallBinaryfile" -e "LSF_INSTALL_ENTITLEMENT_FILE=$lsfInstallEntitlementFile" -e "LSF_CLUSTER_NAME=$lsfClusterName" -e "LSF_MASTER_NAME=$lsfMasterName" -e "LSF_TOP=$lsfTop" -e "LSF_TAR_DIR=$lsfTarDir"  --entrypoint $entryPointFile $IMAGE > /dev/null 2>&1
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
	sasVersion=$2
	#echo -e "hostNum=$hostNum\nsasVersion=$sasVersion"
	#sasInstallPack="$NFS/sas_pss9.1/pm9.1.3.0_sas_lnx26-lib23-x64.tar"
	sasInstallPack="`ls $SAS_INSTALL_PACK | grep tar`"
	sasInstallPack="$SAS_INSTALL_DIR/$sasInstallPack"
	
	#sasInstallEntitlementFile="$NFS/sas_pss9.1/platform_lsf_adv_entitlement.dat"
	sasInstallEntitlementFile="`ls $SAS_INSTALL_PACK | grep enti`"
	sasInstallEntitlementFile="$SAS_INSTALL_DIR/$sasInstallEntitlementFile"
	
	sasFlowEditorFile="$SAS_INSTALL_DIR/floweditor"
	
	#echo -e "sasInstallPack=$sasInstallPack\nsasInstallEntitlementFile=$sasInstallEntitlementFile"
	
	if [ $sasVersion = "pss91" ]; then
		sasInstallDirWithVersion="$SAS_INSTALL_DIR/pm9.1.3.0_sas_pinstall"
	elif [ $sasVersion = "pss81" ]; then
		sasInstallDirWithVersion="$SAS_INSTALL_DIR/pm9.1.0.0_sas_pinstall"
	fi
	isSAS="Y"
	entryPointFile="$NFS/sasinstall.entrypoint.sh"
	export LSF_DOMAIN="sas$ID.com"
	export JS_TOP="$NFS/sas/pm_$sasVersion"
	JS_HOST=master-id$ID
	JS_ADMINS=lsfadmin
	LSF_INSTALL="true"
	export LSF_TOP="$NFS/sas/lsf_$sasVersion"
	export LSF_CLUSTER_NAME="sas"
	LSF_MASTER_LIST="master-id$ID"
	#Input Env Vars: SAS_INSTALL_PACK SAS_INSTALL_ENTITLEMENT_FILE SAS_INSTALL_DIR IS_SAS
	Install="Install-id$ID"
	#echo "docker run -idt --volumes-from $nfs --name $Install -h $JS_HOST --cap-add=SYS_PTRACE -e "ID=$ID" -e "LSF_DOMAIN=$LSF_DOMAIN" -e "HOST_NUM=$hostNum" -e "NFS=$NFS" -e "SAS_INSTALL_PACK=$sasInstallPack" -e "SAS_INSTALL_ENTITLEMENT_FILE=$sasInstallEntitlementFile" -e "SAS_INSTALL_DIR=$SAS_INSTALL_DIR" -e "SAS_INSTALL_DIR_WITH_VERSION=$sasInstallDirWithVersion" -e "IS_SAS=$isSAS" -e "JS_TOP=$JS_TOP" -e "JS_HOST=$JS_HOST" -e "JS_ADMINS=$JS_ADMINS" -e "LSF_INSTALL=$LSF_INSTALL" -e "LSF_TOP=$LSF_TOP" -e "LSF_CLUSTER_NAME=$LSF_CLUSTER_NAME" -e "LSF_MASTER_LIST=$LSF_MASTER_LIST" --entrypoint $entryPointFile $IMAGE4SAS"
	docker run --privileged=true -idt --volumes-from $nfs --name $Install -h $JS_HOST --cap-add=SYS_PTRACE -e "FLOW_EDITOR=$sasFlowEditorFile" -e "ID=$ID" -e "LSF_DOMAIN=$LSF_DOMAIN" -e "HOST_NUM=$hostNum" -e "NFS=$NFS" -e "SAS_INSTALL_PACK=$sasInstallPack" -e "SAS_INSTALL_ENTITLEMENT_FILE=$sasInstallEntitlementFile" -e "SAS_INSTALL_DIR=$SAS_INSTALL_DIR" -e "SAS_INSTALL_DIR_WITH_VERSION=$sasInstallDirWithVersion" -e "IS_SAS=$isSAS" -e "JS_TOP=$JS_TOP" -e "JS_HOST=$JS_HOST" -e "JS_ADMINS=$JS_ADMINS" -e "LSF_INSTALL=$LSF_INSTALL" -e "LSF_TOP=$LSF_TOP" -e "LSF_CLUSTER_NAME=$LSF_CLUSTER_NAME" -e "LSF_MASTER_LIST=$LSF_MASTER_LIST" --entrypoint $entryPointFile $IMAGE4SAS >/dev/null
	docker wait $Install > /dev/null 2>&1
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
	docker run --privileged=true -d --name $dns_server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
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
# To support SMTP
#	docker run --privileged=true -idt -p 25:25 -p 587:587 -p 465:465 --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from $nfs --cap-add=SYS_PTRACE -e "ID=$ID" -e "CLUSTER_NAME=$CLUSTER_NAME" -e "LSF_TOP=$LSF_TOP" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE > /dev/null 2>&1
		
docker run --privileged=true -idt --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from $nfs --cap-add=SYS_PTRACE -e "ID=$ID" -e "CLUSTER_NAME=$CLUSTER_NAME" -e "LSF_TOP=$LSF_TOP" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE > /dev/null 2>&1
		# Generate a hosts file for hostname-IP reverse resolution
		hostIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' $hostName`
		echo "$hostIP $hostName" >> $SSH_AUTO/ip-hosts.$CLUSTER_NAME
		
		echo $hostName >> $SSH_AUTO/hosts.$CLUSTER_NAME
		echo "Created LSF HOST: $hostName"

	done
	
	# Copy hosts file to shared NFS which can be accessed by each container
	# The file is to feed ssh passwd-less function by getting all container host names
	docker cp $SSH_AUTO/hosts.$CLUSTER_NAME $nfs:$NFS/sshnopasswd
	
	# Copy ip-hosts file to the container
	#docker cp $SSH_AUTO/ip-hosts.$CLUSTER_NAME $nfs:$LSF_TOP/conf/hosts
	docker cp $SSH_AUTO/ip-hosts.$CLUSTER_NAME $nfs:$NFS/hosts
	
	# Make $LSF_ENVDIR/hosts point to /opt/hosts
	masterNode="master-id$ID"
	docker exec -it $masterNode bash -c "ln -s $NFS/hosts $LSF_TOP/conf/hosts"
	
	# Start LSF in each container by sending signal SIGUSR1
	for i in `cat $SSH_AUTO/hosts.$CLUSTER_NAME`; do
		docker kill -s SIGUSR1 $i > /dev/null 2>&1
	done
	
	rm $SSH_AUTO/hosts.$CLUSTER_NAME
	rm $SSH_AUTO/ip-hosts.$CLUSTER_NAME
	
	
	echo -e "\nRun the following command to logon the hosts"
	echo "dlogin <hostname> (e.g. dlogin master-id100)"
	
	docker ps | grep elasticsearch > /dev/null
	if [ $? = 0 ]; then
		echo "LSF Explorer is installed, access http://<host_ip>:$WEBPORT"
		echo "e.g. On Mac: http://127.0.0.1:$WEBPORT"
		echo "e.g. On bjhc01: http://bjhc01.eng.platformlab.ibm.com:$WEBPORT"
	fi
}
	


function funcBuildClusterMC() {
	echo "Building MC Cluster..."
	domain="MC${ID}.com"
	echo "Starting DNS Server"
	dns_server="dns-server-id$ID"
	docker run --privileged=true -d --name $dns_server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
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
			docker run --privileged=true -idt --dns $dnsIP --dns-search $domain --name $hostName -h $hostName --volumes-from $nfs --cap-add=SYS_PTRACE -e "CLUSTER_NAME=$clusterName" -e "LSF_TOP=$LSF_TOP" -e "NFS=$NFS" -e "LSF_DOMAIN=$domain" --entrypoint $entrypointBuildLSF $IMAGE > /dev/null 2>&1
		
			echo $hostName >> $SSH_AUTO/hosts.$clusterName
			
			# Generate a hosts file for hostname-IP reverse resolution
			hostIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' $hostName`
			echo "$hostIP $hostName" >> $SSH_AUTO/ip-hosts.$clusterName
			
			echo "Created LSF HOST: $hostName for cluster: $clusterName"

		done
		docker cp $SSH_AUTO/hosts.$clusterName $nfs:$NFS/sshnopasswd
		#docker cp $SSH_AUTO/ip-hosts.$clusterName $nfs:$LSF_TOP/conf/hosts
		cat $SSH_AUTO/ip-hosts.$clusterName >> $SSH_AUTO/ip-hosts.all
		
		rm $SSH_AUTO/hosts.$clusterName
		rm $SSH_AUTO/ip-hosts.$clusterName
	done
	
	# Copy the file ip-hosts.all (It contains all IP address - hostname for each host in all clusters) to /opt/hosts and make all cluster point to this file. 
	# This is to make dstart easily to modify the hosts file. Just modify one place and all clusters can know the change
	
	#NFS_NODE="NFS-id$ID"
	docker cp $SSH_AUTO/ip-hosts.all $nfs:$NFS/hosts
	
	for((k=1;k<=$CLUSTER_NUM;k++))
	do
		clusterName="c$k"
		lsfTop="$NFS/cluster$k"
		LSF_TOP=$lsfTop
		#if [ k=1 ];then
			#docker cp $SSH_AUTO/ip-hosts.all $nfs:$LSF_TOP/conf/hosts
		masterNode="c$k-master-id$ID"
		echo "debug: masterNode=$masterNode"		
		docker exec -it $masterNode bash -c "ln -s $NFS/hosts $LSF_TOP/conf/hosts"
		
	done
	
	# Remove the ip-hosts.all file
	rm $SSH_AUTO/ip-hosts.all
	
	# Start each MC node

	for i in $hostList
	do
		docker kill -s SIGUSR1 $i > /dev/null 2>&1
	done
	
	echo -e "\nRun the following command to logon the hosts"
	echo "dlogin <hostname> (e.g. dlogin c1-master-id001)"
	docker ps | grep elasticsearch > /dev/null
	if [ $? = 0 ]; then
		echo "LSF Explorer is installed, access http://<host_ip>:$WEBPORT"
		echo "e.g. On Mac: http://127.0.0.1:$WEBPORT"
		echo "e.g. On bjhc01: http://bjhc01.eng.platformlab.ibm.com:$WEBPORT"
	fi
}


function funcSASBuild() {
	echo "Building SAS Cluster..."
	domain=$LSF_DOMAIN
	echo "Starting DNS Server"
	dns_server="dns-server-id$ID"
	docker run --privileged=true -d --name $dns_server -v /var/run/docker.sock:/docker.sock phensley/docker-dns:latest  --domain $domain > /dev/null 2>&1
	echo "DNS server is started"

	dnsIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' $dns_server`
	
	hostList=""
	clusterName=$LSF_CLUSTER_NAME
	entrypointBuildSAS="$NFS/buildsas.entrypoint.sh"
	echo "Open XQuartz"
	open -a XQuartz
	ip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
	xhost + $ip 
	hostNum=$1
	for((i=1;i<=$hostNum;i++))
	do
		j=$[$i-1]
		if [ $i -eq 1 ]; then
			hostName="master-id$ID"
			IS_JS_MASTER="Y"			
		else 
			hostName="slave$j-id$ID"
			IS_JS_MASTER="N"
		fi
		hostList="$hostList $hostName"
		docker run --privileged=true -idt --name $hostName -h $hostName --dns $dnsIP --dns-search $domain --volumes-from $nfs --cap-add=SYS_PTRACE -e DISPLAY=$ip:0 -e "CLUSTER_NAME=$clusterName" -e "LSF_TOP=$LSF_TOP" -e "JS_TOP=$JS_TOP" -e "IS_JS_MASTER=$IS_JS_MASTER" -v /tmp/.X11-unix:/tmp/.X11-unix --entrypoint $entrypointBuildSAS $IMAGE4SAS > /dev/null

#docker run --privileged=true -idt -p 25:25 -p 587:587 -p 465:465 --name $hostName -h $hostName --dns $dnsIP --dns-search $domain --volumes-from $nfs --cap-add=SYS_PTRACE -e DISPLAY=$ip:0 -e "CLUSTER_NAME=$clusterName" -e "LSF_TOP=$LSF_TOP" -e "JS_TOP=$JS_TOP" -e "IS_JS_MASTER=$IS_JS_MASTER" -v /tmp/.X11-unix:/tmp/.X11-unix --entrypoint $entrypointBuildSAS $IMAGE4SAS > /dev/null
		
		echo $hostName >> $SSH_AUTO/hosts.$clusterName
		
		# Generate a hosts file for hostname-IP reverse resolution
		hostIP=`docker inspect --format='{{.NetworkSettings.IPAddress}}' $hostName`
		echo "$hostIP $hostName" >> $SSH_AUTO/ip-hosts.$clusterName
		
		echo "Created LSF HOST: $hostName"		
	done
	docker cp $SSH_AUTO/hosts.$clusterName $nfs:$NFS/sshnopasswd
	
	
	# Copy ip-hosts file to the container
	#docker cp $SSH_AUTO/ip-hosts.$CLUSTER_NAME $nfs:$LSF_TOP/conf/hosts
	docker cp $SSH_AUTO/ip-hosts.$clusterName $nfs:$NFS/hosts
	
	# Make $LSF_ENVDIR/hosts point to /opt/hosts
	masterNode="master-id$ID"
	docker exec -it $masterNode bash -c "ln -s $NFS/hosts $LSF_TOP/conf/hosts"
	
	# Start SAS cluster
	for i in $hostList
	do
		docker kill -s SIGUSR1 $i > /dev/null 2>&1
	done	
	rm $SSH_AUTO/hosts.$clusterName	
	rm $SSH_AUTO/ip-hosts.$clusterName

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
	echo -e "	\nIBM LSF Automatic Deployment Tool (beta)\n\n"
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
			
			read -p "Do you want to install Session Scheduler?(y/n)(n)" isSS
			isSS=${isSS:-"n"}
			
			read -p "Do you want to be monitored by LSF Explorer?(y/n)(n)" isLSFExp
			isLSFExp=${isLSFExp:-"n"}
			
			if [ $isLSFExp = "y" ]; then
				echo "Elastic Search needs 2GB memory at least! You need to set it for the docker engine."
				docker ps | grep elasticsearch >> /dev/null # Check if an elasticsearch is running. If yes, no need to install it again. 
				isESRunning=$?
				if [ $isESRunning = "0" ]; then
					export WEBPORT=`docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' elasticsearch | awk '{print $6}'`
				fi
				isLSFExp="$isLSFExp$isESRunning" # y0 or y1
			fi

			if [ ! -x $isESRunning ]; then 
			if [ $isESRunning = "0" ]; then
				export WEBPORT=`docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' elasticsearch | awk '{print $6}'`
			fi			
			fi
			##	Params of funcInitial
			#	productName=$1
			#	version=$2
			#	isLSFExp=$3 If LSF Explorer will be installed

			funcInitial $PRODUCTS_NAME $LSF_VERSION $isLSFExp			
			funcCreateNFS
			
			##	Params of funcLSFExpServerSetup
			#	isLSFExp (y1 - Need to install Elastic Search Sever and Client, y0 - Need to install only Elastic Search Client or n - nothing to do)
			funcLSFExpServerSetup $isLSFExp
			
			
			isDM="N"
			dmVersion="null"
			ecIP=$EC_IP #Global Env Var set by funcLSFExpServerSetup
			#echo "debug: EC_IP=$ecIP"
			##	Params of funcInstall
			#	needInstallPatch=$1
			#	lsfVersion=$2
			#	isDM=$3
			#	dmVersion=$4
			#   isLSFExp=$5
			#	ecIP=$6
			funcInstall $needInstallPatch $lsfVersion $isDM $dmVersion $isLSFExp $ecIP $isSS
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
			
			
			read -p "Do you want to be monitored by LSF Explorer?(y/n)(n)" isLSFExp
			isLSFExp=${isLSFExp:-"n"}
			
			if [ $isLSFExp = "y" ]; then
				echo "Elastic Search needs 2GB memory at least! You need to set it for the docker engine."
				docker ps | grep elasticsearch >> /dev/null # Check if an elasticsearch is running. If yes, no need to install it again. 
				isESRunning=$?
				if [ $isESRunning = "0" ]; then
					export WEBPORT=`docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' elasticsearch | awk '{print $6}'`
				fi
				isLSFExp="$isLSFExp$isESRunning" # y0 or y1
			fi
			
			
			funcInitial $PRODUCTS_NAME $LSF_VERSION $isLSFExp
			funcCreateNFS
						
			##	Params of funcLSFExpServerSetup
			#	isLSFExp (y1 - Need to install Elastic Search Sever and Client, y0 - Need to install only Elastic Search Client or n - nothing to do)
			funcLSFExpServerSetup $isLSFExp
			
			isDM="N"
			dmVersion="null"
			ecIP=$EC_IP #Global Env Var set by funcLSFExpServerSetup
			
			funcInstallMC $needInstallPatch $lsfVersion $isDM $dmVersion $isLSFExp $ecIP
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
			echo -e "1. LSF9.1.3 + DM9.1.3 (Single Cluster)\n"
			echo -e "2. LSF9.1.3 + DM9.1.3 (MC)\n"
			#echo -e "2. LSF10.1 + DM10.1\n"
			read -p "Input:(1)" version
			version=${version:-1}
			if [ $version = "1" -o $version = "2" ];then
				LSF_VERSION=9.1.3
				# To specify $LSF_TOP/<version>/
				lsfVersion=9.1
				dmVersion=9.1
			elif [ $version = "3" -o $version = "4" ];then
				LSF_VERSION=10.1
				# To specify $LSF_TOP/<version>/
				lsfVersion=10.1
				dmVersion=10.1
			else
				echo "Wrong Input. Exit!"
				EXIT
			fi
			
			# Single Cluster + DM
			if [ $version = "1" -o $version = "3" ]; then
				echo "LSF9.1.3 + DM9.1.3 (Single Cluster)"
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
			fi
			
			# MC + DM
			if [ $version = "2" -o $version = "4" ]; then
				echo "LSF9.1.3 + DM9.1.3 (MC)"
				#PRODUCTS_NAME="DM"
				read -p "How many clusters do you want to create?:(4)" cNum
				cNum=${cNum:-4}
				if [ $cNum -lt 2 ]; then
					echo -e "The smallest number of clusters is 2!\n"
					EXIT
				fi
				CLUSTER_NUM=$cNum
				read -p "How many nodes in each cluster?:(3)" hNum
				hNum=${hNum:-3}
				HOST_NUM=$hNum
				if [ $hNum -lt 3 ]; then
					echo -e "DM cluster has 3 hosts at least. Exit..."
					EXIT
				fi
			
				read -p "Do you want to install the latest patch?(y/n)(n)" needInstallPatch
				needInstallPatch=${needInstallPatch:-"n"}
				funcInitial $PRODUCTS_NAME $LSF_VERSION
				funcCreateNFS
				funcInstallMC $needInstallPatch $lsfVersion $isDM $dmVersion
				funcBuildClusterMC
			fi			
			
		;;
		
		"3")
			echo "Choose SAS version:"
			echo -e "1. PSS8.1 (PM9.1)\n2. PSS9.1 (PM9.1.3)"
			read -p "Input:(1)" sasV
			sasV=${sasV:-1}
			if [ $sasV = "1" ]; then
				sasVersion=pss81
			elif [ $sasV = "2" ]; then
				sasVersion=pss91
			else
				echo "Wrong Input. Exit..."
				EXIT
			fi
			
			read -p "How many hosts do you want to create?(2)" hostNum
			hostNum=${hostNum:-2}
			
			funcSASInitial $sasVersion
			funcSASCreateNFS
			funcSASInstall $hostNum $sasVersion
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
		lockOwner="`ls -la | grep .lockfile | awk '{print $3}'`"
		echo "$lockOwner is running the tool in parallel. Please wait..."
		sleep 10		
	else
		touch ./.lockfile
		chmod 600 ./.lockfile
		break
	fi
done

funcUserInteract
funcClean




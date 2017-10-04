#!/bin/bash

# In this entrypointfile it installs LSF Explorer Sever (Elasticsearch) and starts up the service
# Env Vars
# ECPACKAGE

cd /opt/lsfexpinstalldir
tar -zxvf $ECPACKAGE
ecInstallDir=`ls -F | grep '/$' | grep server`
cd $ecInstallDir
export USER=root # This is LSF Explorer10.2 bug. The workaround is to set the user var to root. 
./ExplorerServerInstaller.sh -silent -f ./install.config
. /opt/ibm/lsfsuite/ext/profile.platform
pmcadmin start
pmcadmin list
bash # The container needs to keep alive to provide the elasticsearch and web service
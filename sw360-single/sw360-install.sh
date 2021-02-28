#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Siemens AG, 2013-2020. Part of the SW360 Portal Project.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# provisioning script for deploying prerequisites
# in the Vagrant machine of the SW360 project
#
# initial author: michael.c.jaeger@siemens.com
#         author: cedric.bodet@tngtech.com
#         author: birgit.heydenreich@tngtech.com
#         author: maximilian.huber@tngtech.com
# -----------------------------------------------------------------------------

set -e

configurationFile="$(dirname $0)/configuration.rb"
if [ ! -f $configurationFile ]; then
  configurationFile="/vagrant_shared/configuration.rb"
fi
source $configurationFile

wd=/sw360portal
mavenParameters=""
mavenMemory="-Xmx1024m -XX:MaxPermSize=1024m"

doFrontend=false
doPortlets=false
doBackend=false
doAll=true
doClean=false
doRest=false

resetDosIfNeeded() {
    if $doAll; then
        doAll=false
    fi
}

while (( "$#" )); do
    case $1 in
        -b|--branch)
            shift
            SW360_branch=$1
            ;;
        --gitURL)
            shift
            SW360_gitURL=$1
            ;;
        -s|--skipTests)
            mavenParameters="-DskipTests"
            ;;
        -F|--doFrontend)
            resetDosIfNeeded
            doFrontend=true
            ;;
        -P|--doPortlets)
            resetDosIfNeeded
            doPortlets=true
            ;;
        -B|--doBackend)
            resetDosIfNeeded
            doBackend=true
            ;;
        -R|--doRest)
            resetDosIfNeeded
            doRest=true
            ;;
        -0|--doNothing)
            resetDosIfNeeded
            ;;
        -c|--clean)
            doClean=true
            ;;
        -h|--help)
            echo "$0"
            echo
            echo "  Git related parameter:"
            echo "      -b|--branch branchName  # check out specific branch (overwrites defaults)"
            echo "      --gitURL gitURL         # set git host url (overwrites defaults)"
            echo "  both parameter are ignored, if $SW360_source is set in the configuration file"
            echo
            echo "  Maven related parameter:"
            echo "      -s|--skipTests          # skip test when compiling"
            echo "      -F|--doFrontend         # only(*) compile frontend"
            echo "      -P|--doPortlets         # only(*) compile portlets (subset of frontend)"
            echo "      -B|--doBackend          # only(*) compile backend"
            echo "      -R|--doRest          	# only(*) compile rest services"
            echo "      -0|--doNothing          # compile nothing (can be overwritten by F,P,B)"
            echo "      -c|--clean              # do mvn clean bevore building"
            echo " (*) can be combined"
            echo
            echo "      -h|--help               # show this text"
            echo
            echo "overall configuration is placed in $configurationFile"
            echo
            echo "Example: only restarting servers"
            echo "    $0 -0"
            echo
            echo "Example: build and deploy frontend and backend"
            echo "    $0 -F -B"
            echo
            echo "Example: build portlets without tests"
            echo "    $0 -P -s"
            exit 0
            ;;
        *)
            echo "the given parameter was not recognized: $1"
            exit 1
            ;;
    esac
    shift
done

LOGGING_PREFIX="- [shell-provisioning]"
echo () {
   /bin/echo "${LOGGING_PREFIX}" $@;
}

echo "This is the SW360 installation script"

# Refresh environment variables
for line in $( cat /etc/environment ); do export $line; done

# to set debug ports and mode,if 5005 is mapped by vagrant
if [ ! -z $SW360_tomcat_debug_port ]; then
    defaultOpts=(-p 5005 -d)
else
    defaultOpts=()
fi

# -----------------------------------------------------------------------------

if [ -z $SW360_source ]; then
    if [ ! -z $SW360_branch ]; then
        echo "SW360 will be installed from the following branch: "
        echo $SW360_branch

        if [ -d "$wd/.git/" ]; then
            cd "$wd"
            git checkout $SW360_branch || git checkout -b $SW360_branch
            git fetch
            git reset --hard origin/$SW360_branch
        else
            git clone -b $SW360_branch --single-branch $SW360_gitURL "$wd"
        fi
    else
        if [ -d "$wd/.git/" ]; then
            cd "$wd"
            currentBranch=$(git rev-parse --abbrev-ref HEAD)
            git fetch
            git reset --hard origin/$currentBranch
        else
            git clone --single-branch $SW360_gitURL "$wd"
        fi
    fi
fi

# -----------------------------------------------------------------------------

if [[ "$(ps -faux | grep 'Bootstrap start' | grep -vc grep)" -eq "0" ]]; then
    echo "Starting tomcat"
    eval "$( /vagrant_shared/scripts/catalinaOpts.sh "${defaultOpts[@]}" "$@" )"
    CATALINA_OPTS="${CATALINA_OPTS}" /opt/liferay-ce-portal-7.3.4-ga5/tomcat-9.0.33/bin/startup.sh
    echo "Waiting for reply of tomcat manager..."
    while [[ "$RESULT" -ne "22" ]]; do
        curl --fail http://localhost:8080/manager/html 2> /dev/null || RESULT=$?
        sleep 1
    done
    echo "Tomcat manager replied."
fi

echo "Start of installing of sw360"
cd $wd/

echo "Increasing memory for maven to $mavenMemory"
export MAVEN_OPTS=$mavenMemory

if $doClean; then
    echo "execute mvn clean"
    mvn clean
fi

if $doAll; then
    echo "Start of entire deployment of sw360"
    mvn package -P deploy -Dbase.deploy.dir=. -Dliferay.deploy.dir=${LIFERAY_INSTALL}/deploy -Dbackend.deploy.dir=${LIFERAY_INSTALL}/tomcat-9.0.33/webapps -Drest.deploy.dir=${LIFERAY_INSTALL}/tomcat-9.0.33/webapps $mavenParameters

else
	if $doBackend; then
	    echo "Start of backend deployment of sw360"
	    cd $wd/backend
        mvn package -P deploy -Dbase.deploy.dir=. -Dbackend.deploy.dir=${LIFERAY_INSTALL}/tomcat-9.0.33/webapps $mavenParameters

	    # mvn install -P deploy $mavenParameters
	fi
	if $doRest; then
	    echo "Start of rest services deployment of sw360"
	    cd $wd/rest
        mvn package -P deploy -Dbase.deploy.dir=. -Drest.deploy.dir=${LIFERAY_INSTALL}/tomcat-9.0.33/webapps $mavenParameters

	    # mvn install -P deploy $mavenParameters
	fi

	if $doFrontend; then
	    echo "Start of frontend deployment of sw360"
	    cd $wd/frontend
	    mvn package -P deploy -Dbase.deploy.dir=. -Dliferay.deploy.dir=${LIFERAY_INSTALL}/deploy $mavenParameters

        # mvn install -P deploy $mavenParameters
	elif $doPortlets; then
	    echo "Start of portlets deployment of sw360"
	    cd $wd/frontend/sw360-portlet

	    mvn package -P deploy -Dbase.deploy.dir=. -Dliferay.deploy.dir=${LIFERAY_INSTALL}/deploy $mavenParameters
        # mvn install -P deploy $mavenParameters
	fi
fi
echo "End of frontend sw360 installation"

echo "End of sw360 provisioning"

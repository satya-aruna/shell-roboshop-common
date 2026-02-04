#!/bin/bash

source ./installandsetup.sh

SERVER=$1

START_TIME=$(date +%s)

INSTALL_SETUP $SERVER

END_TIME=$(date +%s)

TOTAL_TIME=$(($END_TIME-$START_TIME))

echo "Script executed in $TOTAL_TIME seconds"





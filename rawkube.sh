#!/bin/bash

# this script starts, stops or check status of the 4 VM's in AWS
# the vms must have tag "cluster=rawkube" to be managed by this script

# Usage: ./rawkube.sh <start|stop|status>

set -e

PROFILE="chen-dev-lumos"

# input verification
if [ -z "$1" ]
then
  echo "Usage: ./rawkube.sh <start|stop|status>"
  exit 1
fi

# check status
if [ "$1" == "status" ]
then
  echo "Checking status of the VM's ..."
  aws ec2 describe-instances \
    --filters "Name=tag:cluster,Values=rawkube" \
    --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]" \
    --output table --profile $PROFILE | tee
  exit 0
fi

# start vms
if [ "$1" == "start" ]
then
  echo "Starting the VM's ..."
  aws ec2 start-instances \
    --instance-ids $(aws ec2 describe-instances \
      --filters "Name=tag:cluster,Values=rawkube" \
      --query "Reservations[*].Instances[*].InstanceId" \
      --output text --profile $PROFILE) --profile $PROFILE | tee
  exit 0
fi

# stop vms
if [ "$1" == "stop" ]
then
  echo "Stopping the VM's ..."
  aws ec2 stop-instances \
    --instance-ids $(aws ec2 describe-instances \
      --filters "Name=tag:cluster,Values=rawkube" \
      --query "Reservations[*].Instances[*].InstanceId" \
      --output text --profile $PROFILE) --profile $PROFILE | tee
  exit 0
fi


#!/bin/bash
#
# get_namespace_status.sh
#
# This script will get the status of each component in the
# provided namespace
#

K8SNS=$1
FINISHED=no

echo ""
echo "Checking status of namespace: ${K8SNS}"

for POD in $(kubectl -n $K8SNS get po | tail -n +2 | awk '{print $1'})
do
	while [ "$FINISHED" != "yes" ]
	do
		echo "POD   : ${POD}"	
		echo "STATUS: $(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')"

		if [ "$(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')" == "Error" ]
		then
			echo "***************************************"
			echo "There was an error deploying pod ${POD}"
			echo "***************************************"
			exit 1337
		elif [ "$(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')" == "ContainerCreating" ]
		then
			echo "sleeping for 15s"
			sleep 15
		elif [ "$(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')" == "Pending" ]
		then
			echo "sleeping for 15s"
			sleep 15
		elif [ "$(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')" == "ImagePullBackOff" ]
                then
                        echo "sleeping for 15s"
                        sleep 15
		elif [ "$(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')" == "ErrImagePull" ]
                then
                        echo "sleeping for 15s"
                        sleep 15
		elif [ "$(kubectl -n $K8SNS get po ${POD} | tail -n +2 | awk '{print $3}')" == "Running" ]
		then
			FINISHED=yes
		else
			echo "*****************************************************************"
			echo "Unable to determine the status of pod ${POD}. Please investigate."
			echo "*****************************************************************"
			exit 1337
		fi
	done
	echo ""
	FINISHED=no
done

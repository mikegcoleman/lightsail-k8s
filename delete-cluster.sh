#! /bin/bash 

for i in `seq 1 3`; do 
    aws lightsail delete-instance --instance-name kube-$i
done
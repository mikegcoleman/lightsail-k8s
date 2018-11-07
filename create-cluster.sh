#! /bin/bash 

if [ "$1" == "" ]; then
    echo "No key file specified - please provide the path to your SSH key"
    exit 1
fi 

echo "Creating Lightsail instances . . . . "
echo "+++++++++++++++++++++++++++++++++++++"

for i in `seq 1 3`; do 
    aws lightsail create-instances \
    --instance-names kube-$i \
    --availability-zone us-west-2a \
    --blueprint-id ubuntu_16_04_2 \
    --bundle-id micro_2_0 \
    --key-pair universal-key \
    --user-data "$(cat ./install-prereqs.sh)"
done

echo "Sleeping for 120 seconds to allow instances to boot up"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"

sleep 120

MASTER_PUB_IP=$(aws lightsail get-instance --instance-name kube-1 | jq -r '.instance.publicIpAddress')
MASTER_PRIV_IP=$(aws lightsail get-instance --instance-name kube-1 | jq -r '.instance.privateIpAddress')
WORKER_1_PUB_IP=$(aws lightsail get-instance --instance-name kube-2 | jq -r '.instance.publicIpAddress')
WORKER_2_PUB_IP=$(aws lightsail get-instance --instance-name kube-3 | jq -r '.instance.publicIpAddress')
HOME=/home/ubuntu
KEY=$1


echo "Master Public IP " $MASTER_PUB_IP
echo "Master Private IP " $MASTER_PRIV_IP


echo "Initializing master node"
echo "++++++++++++++++++++++++"
     
ssh -q -i $KEY ubuntu@$MASTER_PUB_IP sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$MASTER_PRIV_IP

ssh -q -i $KEY ubuntu@$MASTER_PUB_IP mkdir -p $HOME/.kube
ssh -q -i $KEY ubuntu@$MASTER_PUB_IP sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
ssh -q -i $KEY ubuntu@$MASTER_PUB_IP sudo chown 1000:1000 $HOME/.kube/config


ssh -q -i $KEY ubuntu@$MASTER_PUB_IP kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml

echo "Joining 1st worker (IP: " $WORKER_1_PUB_IP ")"
echo "++++++++++++++++++"

JOIN=$(ssh -q -i $KEY ubuntu@$MASTER_PUB_IP sudo kubeadm token create --print-join-command) && echo $JOIN

ssh -q -i $KEY ubuntu@$WORKER_1_PUB_IP sudo $JOIN

echo "Joining 2nd worker (IP: " $WORKER_2_PUB_IP ")"
echo "++++++++++++++++++"

ssh -q -i $KEY ubuntu@$WORKER_2_PUB_IP sudo $JOIN

echo "Cluster up and running"

ssh -q -i $KEY ubuntu@$MASTER_PUB_IP kubectl get nodes






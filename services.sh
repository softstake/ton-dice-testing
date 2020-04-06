#!/bin/bash

#
# Deploy basic TON-dice services in microk8s
# Tested on Mac OS, edits required for linux
#

DOCKER_LOGIN=$1
DOCKER_PASS=$2

# install brew
I=`which brew`
if [ ! "$I" ]
then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"" readonly="readonly
else 
	echo "brew already installed"
fi  

# install multipass
I=`which multipass`
if [ ! "$I" ]
then
	brew cask install multipass
else 
	echo "multipass already installed"
fi  

# clean state
multipass umount microk8s-vm
# multipass stop microk8s-vm
# multipass delete microk8s-vm
# multipass purge

# install microk8s
multipass launch --name microk8s-vm --mem 4G --disk 40G
multipass exec microk8s-vm -- sudo snap install microk8s --classic --channel=1.13/stable
multipass exec microk8s-vm -- sudo iptables -P FORWARD ACCEPT
multipass exec microk8s-vm -- sudo usermod -a -G microk8s ubuntu
multipass exec microk8s-vm -- sudo chown -f -R ubuntu ~/.kubes

sleep 20

multipass exec microk8s-vm -- /snap/bin/microk8s.enable dns registry storage

rm -rf ton-dice-k8s
git clone https://github.com/tonradar/ton-dice-k8s.git

multipass mount ./ton-dice-k8s microk8s-vm:/home/ubuntu/ton-dice-k8s

# log in to a Docker registry and save credentials
multipass exec microk8s-vm -- /snap/bin/microk8s.docker login -u $DOCKER_LOGIN -p $DOCKER_PASS

# clean up
multipass exec microk8s-vm -- /snap/bin/microk8s.kubectl delete all --all

# postgres ups
multipass exec microk8s-vm -- bash -c "/snap/bin/microk8s.docker login && /snap/bin/microk8s.kubectl apply -f ton-dice-k8s/postgres-configmap.yaml -f ton-dice-k8s/postgres-deployment.yaml -f ton-dice-k8s/postgres-service.yaml -f ton-dice-k8s/postgres-storage.yaml"

# ton-dice-web-server up
multipass exec microk8s-vm -- bash -c "/snap/bin/microk8s.docker login && /snap/bin/microk8s.kubectl apply -f ton-dice-k8s/server-configmap.yaml -f ton-dice-k8s/server-deployment.yaml -f ton-dice-k8s/server-service.yaml"

# ton-api up
multipass exec microk8s-vm -- bash -c "/snap/bin/microk8s.docker login && /snap/bin/microk8s.kubectl apply -f ton-dice-k8s/ton-deployment.yaml -f ton-dice-k8s/ton-service.yaml"

# ton-dice-web-worker up
multipass exec microk8s-vm -- bash -c "/snap/bin/microk8s.docker login && /snap/bin/microk8s.kubectl apply -f ton-dice-k8s/worker-configmap.yaml -f ton-dice-k8s/worker-deployment.yaml"

#!/bin/bash

#Install kind
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.17.0/kind-linux-amd64
chmod +x ./kind && mv ./kind /usr/bin/kind

#Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/bin/kubectl

#Install helm
wget -O helm.tar.gz https://get.helm.sh/helm-v3.10.2-linux-amd64.tar.gz
tar xvzf helm.tar.gz && mv linux-amd64/helm /usr/bin/helm

#Install k9s
wget -O k9s_Linux_x86_64.tar.gz https://github.com/derailed/k9s/releases/download/v0.26.6/k9s_Linux_x86_64.tar.gz 
tar xvzf k9s_Linux_x86_64.tar.gz 
mv k9s /usr/bin/

#Install kubectl-neat
wget -O kubectl-neat.tar.gz https://github.com/itaysk/kubectl-neat/releases/download/v2.0.3/kubectl-neat_darwin_amd64.tar.gz
tar xvzf kubectl-neat.tar.gz && mv kubectl-neat /usr/bin/kubectl-neat 

#Install docker
curl -fsSL https://get.docker.com/ | sh

#Adjust system paramters to enable larger kind clusters
echo "fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288" > /etc/sysctl.d/local.conf
sysctl -p /etc/sysctl.d/local.conf

#Add kubectl bash completion
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
source /etc/bash_completion.d/kubectl

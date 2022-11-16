#!/bin/bash

#Login to the server
# ssh ubuntu@server.dev.kind.learn.entigo.io
# ssh ubuntu@server.test.kind.learn.entigo.io
# ssh ubuntu@server.prod.kind.learn.entigo.io
#Clone the repo and install dependencies
# For dev
git clone --branch dev https://github.com/entigolabs/mets-2022-demo.git
# For test and prod
# git clone --branch main https://github.com/entigolabs/mets-2022-demo.git

#Instlal dependencies (helm, kubectl, kind...)
cd mets-2022-demo && ./install-dependencies.sh

#Create kind kubernetes clusters
kind create cluster --config kind.yaml

#List kind clusters
kubectl config get-contexts

#Argocd bootstrap
kubectl create ns argocd
helm template argocd-yaml/argocd/ | kubectl apply -n argocd -f- 

#Get argocd password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

#Create argocd app-of-apps
  #For dev
  helm template argocd-yaml/app-of-apps/ --set runenv="dev" --set gitbranch="dev" --set gitrepo="https://github.com/entigolabs/mets-2022-demo.git"  | kubectl apply -n argocd -f-
  #For test
  helm template argocd-yaml/app-of-apps/ --set runenv="test" --set gitbranch="main" --set gitrepo="https://github.com/entigolabs/mets-2022-demo.git"  | kubectl apply -n argocd -f-
  #For prod
  helm template argocd-yaml/app-of-apps/ --set runenv="prod" --set gitbranch="main" --set gitrepo="https://github.com/entigolabs/mets-2022-demo.git"  | kubectl apply -n argocd -f-


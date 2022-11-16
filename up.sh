#!/bin/bash

#Login to the server
# ssh ubuntu@server.dev.kind.learn.entigo.io
# ssh ubuntu@server.test.kind.learn.entigo.io
# ssh ubuntu@server.prod.kind.learn.entigo.io
#Clone the repo and install dependencies
# For dev
git clone --branch dev https://github.com/entigolabs/mets-2022.git
# For test and prod
# git clone --branch main https://github.com/entigolabs/mets-2022.git

#Instlal dependencies (helm, kubectl, kind...)
cd mets-2022 && ./install-dependencies.sh

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
  helm template argocd-yaml/app-of-apps/ --set runenv="dev" --set domain="dev.kind.learn.entigo.io" --set gitbranch="dev" --set gitrepo="https://github.com/entigolabs/mets-2022.git"  | kubectl apply -n argocd -f-
  #For test
  helm template argocd-yaml/app-of-apps/ --set runenv="test" --set domain="test.kind.learn.entigo.io" --set gitbranch="main" --set gitrepo="https://github.com/entigolabs/mets-2022.git"  | kubectl apply -n argocd -f-
  #For prod
  helm template argocd-yaml/app-of-apps/ --set runenv="prod" --set domain="prod.kind.learn.entigo.io" --set gitbranch="main" --set gitrepo="https://github.com/entigolabs/mets-2022.git"  | kubectl apply -n argocd -f-


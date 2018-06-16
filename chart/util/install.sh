#!/bin/bash

release=$(<release)

helm install /export/helm-charts/incubator/kerberos --name $release 

#!/bin/bash

region=REGION
used=`df -h --total | grep total | awk '{print $3}' | sed 's/.$//'`
total=`df -h --total | grep total | awk '{print $4}' | sed 's/.$//'`
value=$(echo "($used/$total)*100" | bc -l | grep -o '[0-9]*\.[0-9]\{2\}')

/usr/bin/aws cloudwatch put-metric-data \
  --namespace DevOpsED \
  --metric-name DiskUsed \
  --dimensions "Hostname=$(hostname)" \
  --region "$region" \
  --unit Percent \
  --value "$value"

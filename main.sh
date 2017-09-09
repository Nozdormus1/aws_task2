#!/bin/bash
# GLOBAL VARS: THESE SHOULD BE CHANGED
VPC_ID=vpc-c842cdad
SUBNETS='subnet-bed9b9c9,subnet-f9269ca0,subnet-ca2952af'
KEY_NAME=test_terr

# LOCAL VARS
JNLP_PORT=8082
REGION=eu-west-1
AMI=ami-ebd02392

MY_IP=$(curl ipinfo.io/ip)
MASTER_SUBNET=$(echo ${SUBNETS} | cut -d, -f1 | cut -d\' -f2)
SLAVE_PASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
sed -i "s/SLAVE_PASSWD/${SLAVE_PASSWD}/" userdata_master.sh
sed -i "s/SLAVE_PASSWD/${SLAVE_PASSWD}/" userdata_slave.sh
sed -i "s/JNLP_PORT/${JNLP_PORT}/" userdata_master.sh
MASTER_SG=$(aws ec2 create-security-group --group-name JenkinsMaster --description "Jenkins Master sg" --vpc-id $VPC_ID --query 'GroupId' | sed 's/\"//g')
SLAVE_SG=$(aws ec2 create-security-group --group-name JenkinsSlave --description "Jenkins Slave sg" --vpc-id $VPC_ID --query 'GroupId' | sed 's/\"//g')
aws ec2 authorize-security-group-ingress --group-id ${MASTER_SG} --protocol tcp --port 8080 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id ${MASTER_SG} --protocol tcp --port 22 --cidr ${MY_IP}/32
aws ec2 authorize-security-group-ingress --group-id ${MASTER_SG} --protocol tcp --port ${JNLP_PORT} --cidr 0.0.0.0/0
EIP_INFO=$(aws ec2 allocate-address --domain vpc --query '[PublicIp, AllocationId]' --region ${REGION} | sed 's/\"//g')
MASTER_EIP=$(echo ${EIP_INFO} | cut -d, -f1 | cut -c 3-)
MASTER_EIP_ID=$(echo ${EIP_INFO} | cut -d, -f2 | cut -c 2- | rev | cut -c 2- | rev)
MASTER_INSTANCE_ID=$(aws ec2 run-instances --image-id ${AMI} --count 1 --instance-type t2.micro --key-name ${KEY_NAME} --security-group-ids ${MASTER_SG} --associate-public-ip-address --block-device-mappings file://mapping.json --user-data file://userdata_master.sh --subnet-id ${MASTER_SUBNET} --query Instances[0].InstanceId --region ${REGION} | sed 's/\"//g')
sleep 360
aws ec2 associate-address --instance-id ${MASTER_INSTANCE_ID} --allocation-id ${MASTER_EIP_ID}
sed -i "s/MASTER_EIP/${MASTER_EIP}/" userdata_slave.sh
aws autoscaling create-launch-configuration --launch-configuration-name JenkinsSlaveLC --key-name ${KEY_NAME} --image-id ${AMI} --instance-type t2.micro --user-data file://userdata_slave.sh --security-groups ${SLAVE_SG} --associate-public-ip-address --region ${REGION}
aws autoscaling create-auto-scaling-group --auto-scaling-group-name JenkinsSlaveASG --launch-configuration-name JenkinsSlaveLC --min-size 1 --max-size 3 --desired-capacity 2 --vpc-zone-identifier ${SUBNETS}

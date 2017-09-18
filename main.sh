#!/bin/bash
# GLOBAL VARS: THESE SHOULD BE CHANGED
KEY_NAME=KEY_PAIR_NAME

# LOCAL VARS
JNLP_PORT=8082
REGION=eu-west-1
AMI=ami-ebd02392


# CREATE VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' | sed 's/\"//g')
PUBLIC_SUBNET=$(aws ec2 create-subnet --vpc-id ${VPC_ID} --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' | sed 's/\"//g')
PRIVATE_SUBNET=$(aws ec2 create-subnet --vpc-id ${VPC_ID} --cidr-block 10.0.0.0/24 --query 'Subnet.SubnetId' | sed 's/\"//g')
IGWAY=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' | sed 's/\"//g')
aws ec2 attach-internet-gateway --vpc-id ${VPC_ID} --internet-gateway-id ${IGWAY}
PUBLIC_ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --query 'RouteTable.RouteTableId' | sed 's/\"//g')
aws ec2 create-route --route-table-id ${PUBLIC_ROUTE_TABLE} --destination-cidr-block 0.0.0.0/0 --gateway-id ${IGWAY}
aws ec2 associate-route-table --subnet-id ${PUBLIC_SUBNET} --route-table-id ${PUBLIC_ROUTE_TABLE}
NAT_EIP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region ${REGION} | sed 's/\"//g')
echo $NAT_EIP
NAT_GWAY=$(aws ec2 create-nat-gateway --subnet-id ${PUBLIC_SUBNET} --allocation-id ${NAT_EIP} --query 'NatGateway.NatGatewayId' | sed 's/\"//g')
PRIVATE_ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --query 'RouteTable.RouteTableId' | sed 's/\"//g')
while true
do
    if aws ec2 describe-nat-gateways --nat-gateway-ids ${NAT_GWAY} | grep available
    then
        aws ec2 create-route --route-table-id ${PRIVATE_ROUTE_TABLE} --destination-cidr-block 0.0.0.0/0 --nat-gateway-id ${NAT_GWAY}
        break
    fi
    sleep 60
done
aws ec2 associate-route-table --subnet-id ${PRIVATE_SUBNET} --route-table-id ${PRIVATE_ROUTE_TABLE}


# CREATE ROLE
ROLE_NAME=devops_ed
POLICY_NAME=devops_ed_cwt_policy

aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://assume_policy.json
aws iam put-role-policy --policy-name ${POLICY_NAME} --role-name ${ROLE_NAME} --policy-document file://cwt_role.json
aws iam create-instance-profile --instance-profile-name ${ROLE_NAME}
aws iam add-role-to-instance-profile --instance-profile-name ${ROLE_NAME} --role-name ${ROLE_NAME}


# LAUNCH JENKINS INSTANCES
MY_IP=$(curl ipinfo.io/ip)
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
MASTER_INSTANCE_ID=$(aws ec2 run-instances --image-id ${AMI} --count 1 --instance-type t2.micro --key-name ${KEY_NAME} --security-group-ids ${MASTER_SG} --associate-public-ip-address --iam-instance-profile Name=${ROLE_NAME} --block-device-mappings file://mapping.json --user-data file://userdata_master.sh --subnet-id ${PUBLIC_SUBNET} --query Instances[0].InstanceId --region ${REGION} | sed 's/\"//g')
sleep 360
aws ec2 associate-address --instance-id ${MASTER_INSTANCE_ID} --allocation-id ${MASTER_EIP_ID}
sed -i "s/MASTER_EIP/${MASTER_EIP}/" userdata_slave.sh
aws autoscaling create-launch-configuration --launch-configuration-name JenkinsSlaveLC --key-name ${KEY_NAME} --image-id ${AMI} --instance-type t2.micro --user-data file://userdata_slave.sh --security-groups ${SLAVE_SG} --iam-instance-profile ${ROLE_NAME} --associate-public-ip-address --region ${REGION}
aws autoscaling create-auto-scaling-group --auto-scaling-group-name JenkinsSlaveASG --launch-configuration-name JenkinsSlaveLC --min-size 1 --max-size 3 --desired-capacity 2 --vpc-zone-identifier ${PRIVATE_SUBNET}

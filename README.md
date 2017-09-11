# Jenkins aws task
## Requirments
- aws account
- aws cli installed and configured
- exisitng VPC on aws account with subnets
- existing key pair on ec2
## Prerequisite
- change VPC_ID=\<your VPC\>, SUBNETS='<subnet 1>,<subnet 2>,<subnet 3>', KEY_NAME=\<your key pair\> in main.sh file
## Launch
For launching stack perform:
`./main.sh` in the root of git project directory

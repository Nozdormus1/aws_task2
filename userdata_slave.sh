#!/bin/bash
yum -y update
yum -y install java-1.8.0-openjdk.x86_64
echo 2 | update-alternatives --config java
wget https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/3.3/swarm-client-3.3.jar
java -jar swarm-client-3.3.jar -master http://MASTER_EIP:8080/ -username 'slave' -password 'SLAVE_PASSWD'

#!/bin/bash
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
mkdir /var/lib/jenkins
mkfs.ext4 /dev/xvdb
mount /dev/xvdb /var/lib/jenkins
yum -y update
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
yum -y install jenkins java-1.8.0-openjdk.x86_64
echo 2 | update-alternatives --config java
service jenkins start
sleep 180
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth admin:$(cat /var/lib/jenkins/secrets/initialAdminPassword) install-plugin swarm
service jenkins restart
sleep 180
echo 'jenkins.model.Jenkins.instance.securityRealm.createAccount("slave", "SLAVE_PASSWD")' | java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(cat /var/lib/jenkins/secrets/initialAdminPassword) groovy =
echo 'jenkins.model.Jenkins.instance.setSlaveAgentPort(JNLP_PORT)' | java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(cat /var/lib/jenkins/secrets/initialAdminPassword) groovy =
/usr/bin/aws s3 cp s3://my-bucket-ACCOUNT_ID/dfree.sh /usr/bin/dfree.sh
chmod 755 /usr/bin/dfree.sh
cat <(echo "*/5 * * * * /usr/bin/dfree.sh") | crontab -

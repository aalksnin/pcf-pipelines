#!/bin/bash
set -e

echo "$PEM" > pcf.pem
chmod 0600 pcf.pem

CWD=$(pwd)
pushd $CWD
  cd pcf-pipelines/install-pcf/aws/terraform/
  cp $CWD/terraform-state/terraform.tfstate .

  while read -r line
  do
    `echo "$line" | awk '{print "export "$1"="$3}'`
  done < <(terraform output -state *.tfstate)

  export RDS_PASSWORD=`terraform state show aws_db_instance.pcf_rds | grep ^password | awk '{print $3}'`
popd

cat > databases.sql <<EOF
CREATE DATABASE IF NOT EXISTS console;

CREATE DATABASE IF NOT EXISTS uaa;
CREATE USER IF NOT EXISTS '$DB_UAA_USERNAME' IDENTIFIED BY '$DB_UAA_PASSWORD';
GRANT ALL ON uaa.* TO '$DB_UAA_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS ccdb;
CREATE USER IF NOT EXISTS '$DB_CCDB_USERNAME' IDENTIFIED BY '$DB_CCDB_PASSWORD';
GRANT ALL ON ccdb.* TO '$DB_CCDB_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS notifications;
CREATE USER IF NOT EXISTS '$DB_NOTIFICATIONS_USERNAME' IDENTIFIED BY '$DB_NOTIFICATIONS_PASSWORD';
GRANT ALL ON notifications.* TO '$DB_NOTIFICATIONS_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS autoscale;
CREATE USER IF NOT EXISTS '$DB_AUTOSCALE_USERNAME' IDENTIFIED BY '$DB_AUTOSCALE_PASSWORD';
GRANT ALL ON autoscale.* TO '$DB_AUTOSCALE_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS app_usage_service;
CREATE USER IF NOT EXISTS '$DB_APP_USAGE_SERVICE_USERNAME' IDENTIFIED BY '$DB_APP_USAGE_SERVICE_PASSWORD';
GRANT ALL ON app_usage_service.* TO '$DB_APP_USAGE_SERVICE_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS routing;
CREATE USER IF NOT EXISTS '$DB_ROUTING_USERNAME' IDENTIFIED BY '$DB_ROUTING_PASSWORD';
GRANT ALL ON routing.* TO '$DB_ROUTING_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS diego;
CREATE USER IF NOT EXISTS '$DB_DIEGO_USERNAME' IDENTIFIED BY '$DB_DIEGO_PASSWORD';
GRANT ALL ON diego.* TO '$DB_DIEGO_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS account;
CREATE USER IF NOT EXISTS '$DB_ACCOUNTDB_USERNAME' IDENTIFIED BY '$DB_ACCOUNT_PASSWORD';
GRANT ALL ON account.* TO '$DB_ACCOUNTDB_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS nfsvolume;
CREATE USER IF NOT EXISTS '$DB_NFSVOLUMEDB_USERNAME' IDENTIFIED BY '$DB_NFSVOLUMEDB_PASSWORD';
GRANT ALL ON nfsvolume.* TO '$DB_NFSVOLUMEDB_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS networkpolicyserver;
CREATE USER IF NOT EXISTS '$DB_NETWORKPOLICYSERVERDB_USERNAME' IDENTIFIED BY '$DB_NETWORKPOLICYSERVERDB_PASSWORD';
GRANT ALL ON networkpolicyserver.* TO '$DB_NETWORKPOLICYSERVERDB_USERNAME'@'%';
EOF

scp -i pcf.pem -o StrictHostKeyChecking=no databases.sql ubuntu@opsman.${ERT_DOMAIN}:/tmp/.
ssh -i pcf.pem -o StrictHostKeyChecking=no ubuntu@opsman.${ERT_DOMAIN} "mysql -h $db_host -u $db_username -p$RDS_PASSWORD < /tmp/databases.sql"

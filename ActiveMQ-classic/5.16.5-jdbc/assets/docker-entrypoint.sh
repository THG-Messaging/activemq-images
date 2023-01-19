#!/bin/sh
set -x
sed -i "s/broker_name/${BROKER_NAME}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_HOST/${DB_HOST}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_USERNAME/${DB_USERNAME}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_PASSWORD/${DB_PASSWORD}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_NAME/${DB_NAME}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/CREATE_DB_TABLES/${CREATE_DB_TABLES}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i 's/127.0.0.1/0.0.0.0/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty.xml
# @ToDO need to test this auth property line as it repeats in few lines
sed -i 's/<property name="authenticate" value="true" \/\>/<property name="authenticate" value="true" \/\>/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
sed -i "s/admin: admin, admin/admin: ${ACTIVEMQ_ADMIN_PASS}, admin/g" $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
bin/activemq console

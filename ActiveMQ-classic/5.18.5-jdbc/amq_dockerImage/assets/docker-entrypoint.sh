#!/bin/sh
if [ "$DEBUG" = "true" ] ; then
set -x
else
set +x
fi
# @ToDo make JMX optional and make it more secure
echo 'ACTIVEMQ_OPTS="$ACTIVEMQ_OPTS -Djava.rmi.server.hostname=0.0.0.0 -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.rmi.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=${ACTIVEMQ_BASE}/conf/jmx.password -Dcom.sun.management.jmxremote.access.file=${ACTIVEMQ_BASE}/conf/jmx.access"' >> /opt/apache-activemq-${AMQ_VERSION}/bin/env
sed -i "s/BROKER_NAME/${BROKER_NAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_HOST/${DB_HOST}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s|JDBC_URL|$(echo "$JDBC_URL" | sed 's|&|\\&amp;|g')|g" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/node-ID/${BROKER_NAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_USERNAME/${DB_USERNAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_PASSWORD/${DB_PASSWORD}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
# sed -i "s/DB_NAME/${DB_NAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
if [ "$SCHEDULER_SUPPORT" = true ] ; then
sed -i "s/SCHEDULER_SUPPORT/${SCHEDULER_SUPPORT}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
else
sed -i "s/SCHEDULER_SUPPORT/false/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
if [ "$CREATE_DB_TABLES" = true ] ; then
sed -i "s/CREATE_DB_TABLES/${CREATE_DB_TABLES}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
else
sed -i "s/CREATE_DB_TABLES/false/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
sed -i "s/USE_JMX/${USE_JMX}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/127.0.0.1/0.0.0.0/g" $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/jetty.xml
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/jmx.password
sed -i "s/CONTROL_ROLE_PASS/${CONTROL_ROLE_PASS}/" $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/jmx.password
if [ "$OPENWIRE_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"openwire\" uri=\"tcp:\/\/0.0.0.0:$OPENWIRE_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600&amp;transport.soTimeout=$SOTIMEOUT&amp;transport.soWriteTimeout=$SOWRITETIMEOUT\"\/\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
if [ "$OPENWIRE_SSL_ENABLED" = true ] ; then
keytool -genkey -alias broker -keyalg RSA -keystore /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/broker.ks -storepass $KS_PASSWORD -keypass $KS_PASSWORD -dname "CN=$CN, OU=ct, O=st" -validity 3600
keytool -export -alias broker -keystore /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/broker.ks -file /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/broker_cert  -storepass $KS_PASSWORD
keytool -genkey -alias client -keyalg RSA -keystore /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/client.ks -storepass $KS_PASSWORD -keypass $KS_PASSWORD -dname "CN=$CN, OU=zen, O=st" -validity 700
keytool -import -noprompt -alias broker -keystore /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/client.ts -file /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/broker_cert -storepass $KS_PASSWORD
keytool -export -alias client -keystore /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/client.ks -file /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/client_cert -storepass $KS_PASSWORD
keytool -import -noprompt -alias client -keystore /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/broker.ts -file /opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/client_cert -storepass $KS_PASSWORD
sed -i "/<!--sslPlaceholder-->/a\\ \t\t<sslContext\><sslContext keyStore=\"/opt/apache-activemq-${AMQ_VERSION}/conf/security/ssl/$KS_FILE\" keyStorePassword=\"$KS_PASSWORD\"/></sslContext\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"ssl\" uri=\"ssl:\/\/0.0.0.0:$OPENWIRE_SSL_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600&amp;transport.soTimeout=$SOTIMEOUT&amp;transport.soWriteTimeout=$SOWRITETIMEOUT\"\/\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
if [ "$AMQP_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"amqp\" uri=\"tcp:\/\/0.0.0.0:$AMQP_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
if [ "$STOMP_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"stomp\" uri=\"tcp:\/\/0.0.0.0:$STOMP_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
if [ "$MQTT_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"mqtt\" uri=\"tcp:\/\/0.0.0.0:$MQTT_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
fi
# @ToDO need to test this auth property line as it repeats in few lines
sed -i 's/<property name="authenticate" value="true" \/\>/<property name="authenticate" value="true" \/\>/g' $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/jetty.xml
sed -i "s/admin: admin, admin/admin: ${ACTIVEMQ_ADMIN_PASS}, admin/g" $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/jetty-realm.properties

# Activemq UI admin
sed -i "s/activemq.username=system/activemq.username=admin/" /opt/apache-activemq-${AMQ_VERSION}/conf/credentials.properties
sed -i "s/activemq.password=manager/activemq.password=${ACTIVEMQ_ADMIN_PASS}/" /opt/apache-activemq-${AMQ_VERSION}/conf/credentials.properties

sed -i "s/admin=admin/admin=${ACTIVEMQ_ADMIN_PASS}/" /opt/apache-activemq-${AMQ_VERSION}/conf/security/users/users.properties

# JMX exporter
if [ "$METRICS_ENABLED" = true ] ; then
sed -i -e $'$a\\\nACTIVEMQ_OPTS="-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent-1.2.0.jar=${METRICS_PORT}:/opt/jmx_exporter/config.yaml"' /opt/apache-activemq-${AMQ_VERSION}/bin/env
fi
bin/activemq console 'xbean:../conf/activemq.xml?validate=false' & /opt/apache-activemq-${AMQ_VERSION}/conf/monitor_bridges.sh
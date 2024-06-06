#!/bin/sh
if [ "$DEBUG" = "true" ] ; then
set -x
else
set +x
fi
# @ToDo make JMX optional and make it more secure
echo 'ACTIVEMQ_OPTS="$ACTIVEMQ_OPTS -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.rmi.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=${ACTIVEMQ_BASE}/conf/jmx.password -Dcom.sun.management.jmxremote.access.file=${ACTIVEMQ_BASE}/conf/jmx.access -Dhawtio.authenticationEnabled=false -Dhawtio.realm=activemq -Dhawtio.role=admins -Dhawtio.rolePrincipalClasses=org.apache.activemq.jaas.GroupPrincipal"' >> /opt/apache-activemq-${AMQ_VERSION}/bin/env
sed -i "s/BROKER_NAME/${BROKER_NAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_HOST/${DB_HOST}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/node-ID/${BROKER_NAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_USERNAME/${DB_USERNAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_PASSWORD/${DB_PASSWORD}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
sed -i "s/DB_NAME/${DB_NAME}/" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
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
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" $CONTAINER_METRICS/config.yaml
if [ "$OPENWIRE_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"openwire\" uri=\"tcp:\/\/0.0.0.0:$OPENWIRE_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
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

# @ToDo make prom exporter as optional
if [ "$METRICS_ENABLED" = true ] ; then
java -jar ${CONTAINER_METRICS}/jmx_prometheus_httpserver-${PROM_EXPORTER_VERSION}.jar 12345 ${CONTAINER_METRICS}/config.yaml &
fi
bin/activemq console 'xbean:../conf/activemq.xml?validate=false'
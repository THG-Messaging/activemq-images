#!/bin/sh
set -x
# @ToDo make JMX optional and make it more secure
echo '\nACTIVEMQ_OPTS="$ACTIVEMQ_OPTS -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.rmi.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=${ACTIVEMQ_BASE}/conf/jmx.password -Dcom.sun.management.jmxremote.access.file=${ACTIVEMQ_BASE}/conf/jmx.access -Dhawtio.authenticationEnabled=false -Dhawtio.realm=activemq -Dhawtio.role=admins -Dhawtio.rolePrincipalClasses=org.apache.activemq.jaas.GroupPrincipal"' >> /opt/apache-activemq-5.18.3/bin/env
sed -i "s/broker_name/${BROKER_NAME}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
sed -i "s/node-ID/${BROKER_NAME}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
sed -i "s/DB_HOST/${DB_HOST}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
sed -i "s/DB_USERNAME/${DB_USERNAME}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
sed -i "s/DB_PASSWORD/${DB_PASSWORD}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
sed -i "s/DB_NAME/${DB_NAME}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
if [ "$OPENWIRE_ENABLED" = true ] ; then
sed -i "s/CREATE_DB_TABLES/${CREATE_DB_TABLES}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
else
sed -i "s/CREATE_DB_TABLES/false/" /opt/apache-activemq-5.18.3/conf/activemq.xml
fi
sed -i "s/USE_JMX/${USE_JMX}/" /opt/apache-activemq-5.18.3/conf/activemq.xml
sed -i 's/127.0.0.1/0.0.0.0/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jetty.xml
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jmx.password
sed -i "s/CONTROL_ROLE_PASS/${CONTROL_ROLE_PASS}/" $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jmx.password
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" $CONTAINER_METRICS/config.yaml
if [ "$OPENWIRE_ENABLED" = true ] ; then
sed -i "/\t<transportConnectors\>/a\\ \t\t<transportConnector name=\"openwire\" uri=\"tcp:\/\/0.0.0.0:$OPENWIRE_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-5.18.3/conf/activemq.xml
fi
if [ "$AMQP_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"amqp\" uri=\"tcp:\/\/0.0.0.0:$AMQP_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-5.18.3/conf/activemq.xml
fi
if [ "$STOMP_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"stomp\" uri=\"tcp:\/\/0.0.0.0:$STOMP_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-5.18.3/conf/activemq.xml
fi
if [ "$MQTT_ENABLED" = true ] ; then
sed -i "/<transportConnectors\>/a\\ \t\t<transportConnector name=\"mqtt\" uri=\"tcp:\/\/0.0.0.0:$MQTT_PORT?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600\"\/\>" /opt/apache-activemq-5.18.3/conf/activemq.xml
fi
# @ToDO need to test this auth property line as it repeats in few lines
sed -i 's/<property name="authenticate" value="true" \/\>/<property name="authenticate" value="true" \/\>/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jetty-realm.properties
sed -i "s/admin: admin, admin/admin: ${ACTIVEMQ_ADMIN_PASS}, admin/g" $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jetty-realm.properties
# @ToDo make prom exporter as optional
if [ "$METRICS_ENABLED" = true ] ; then
java -jar ${CONTAINER_METRICS}/jmx_prometheus_httpserver-0.17.2.jar 12345 ${CONTAINER_METRICS}/config.yaml &
fi
bin/activemq console 'xbean:../conf/activemq.xml?validate=false'
#!/bin/sh
set -x
# @ToDo make JMX optional and make it more secure
echo '\nACTIVEMQ_OPTS="$ACTIVEMQ_OPTS -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.rmi.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=${ACTIVEMQ_BASE}/conf/jmx.password -Dcom.sun.management.jmxremote.access.file=${ACTIVEMQ_BASE}/conf/jmx.access -Dhawtio.authenticationEnabled=false -Dhawtio.realm=activemq -Dhawtio.role=admins -Dhawtio.rolePrincipalClasses=org.apache.activemq.jaas.GroupPrincipal"' >> /opt/apache-activemq-5.16.5/bin/env
sed -i "s/broker_name/${BROKER_NAME}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_HOST/${DB_HOST}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_USERNAME/${DB_USERNAME}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_PASSWORD/${DB_PASSWORD}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/DB_NAME/${DB_NAME}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/CREATE_DB_TABLES/${CREATE_DB_TABLES}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i "s/USE_JMX/${USE_JMX}/" /opt/apache-activemq-5.16.5/conf/activemq.xml
sed -i 's/127.0.0.1/0.0.0.0/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty.xml
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jmx.password
sed -i "s/CONTROL_ROLE_PASS/${CONTROL_ROLE_PASS}/" $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jmx.password
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" $CONTAINER_METRICS/config.yaml
# @ToDO need to test this auth property line as it repeats in few lines
sed -i 's/<property name="authenticate" value="true" \/\>/<property name="authenticate" value="true" \/\>/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
sed -i "s/admin: admin, admin/admin: ${ACTIVEMQ_ADMIN_PASS}, admin/g" $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
echo labas
echo $MONITOR_ROLE_PASS
# @ToDo make prom exporter as optional
if [ "$METRICS_ENABLED" = true ] ; then
java -jar ${CONTAINER_METRICS}/jmx_prometheus_httpserver-0.17.2.jar 12345 ${CONTAINER_METRICS}/config.yaml &
fi
bin/activemq console
# @ToDo maybe use Alpine for lightweight?
#FROM alpine 
FROM adoptopenjdk/openjdk11-openj9

ENV ACTIVEMQ_WORKDIR /opt
ENV CONTAINER_METRICS /opt/metrics
ENV BROKER_NAME \
    DB_HOST \
    DB_USERNAME \
    DB_PASSWORD \
    DB_NAME \
    CREATE_DB_TABLES \
    ACTIVEMQ_ADMIN_PASS \
    METRICS_ENABLED \
    USE_JMX \
    CONTROL_ROLE_PASS \
    MONITOR_ROLE_PASS \
    OPENWIRE_ENABLED \
    OPENWIRE_PORT \
    AMQP_ENABLED \
    AMQP_PORT \
    STOMP_ENABLED \
    STOMP_PORT \
    MQTT_ENABLED \
    MQTT_PORT
    
RUN apt update
RUN apt install wget vim -y \
    && mkdir -p $ACTIVEMQ_WORKDIR \
    && mkdir -p $CONTAINER_METRICS
RUN wget https://archive.apache.org/dist/activemq/5.18.3/apache-activemq-5.18.3-bin.tar.gz \
    && wget https://repo1.maven.org/maven2/com/zaxxer/HikariCP/5.0.0/HikariCP-5.0.0.jar \
    && wget https://repo1.maven.org/maven2/org/postgresql/postgresql/42.3.1/postgresql-42.3.1.jar \
    && wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_httpserver/0.17.2/jmx_prometheus_httpserver-0.17.2.jar
RUN tar -xzf apache-activemq-5.18.3-bin.tar.gz -C $ACTIVEMQ_WORKDIR \
    && rm \apache-activemq-5.18.3-bin.tar.gz \
    && mv HikariCP-5.0.0.jar $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/lib/optional/HikariCP-5.0.0.jar \
    && mv postgresql-42.3.1.jar $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/lib/optional/postgresql-42.3.1.jar\
    && mv jmx_prometheus_httpserver-0.17.2.jar $CONTAINER_METRICS
# ToDoremove .tar
# users and hosts should go through vars through entrypoint?    

COPY assets/activemq.xml $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/activemq.xml
COPY assets/bridges.xml $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/bridges.xml
COPY assets/docker-entrypoint.sh /
COPY assets/config.yaml $CONTAINER_METRICS/config.yaml
COPY assets/conf $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf
RUN chmod -R 600 $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jmx.access $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/jmx.password
RUN chmod 777 /docker-entrypoint.sh

WORKDIR $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/

EXPOSE 8161 61616

ENTRYPOINT ["/docker-entrypoint.sh"]
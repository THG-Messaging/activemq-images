# @ToDo maybe use Alpine for lightweight?
#FROM alpine 
FROM adoptopenjdk/openjdk11-openj9

ARG AMQ_VERSION \
    PROM_EXPORTER_VERSION \
    POSTGRESQL_JDBC_DRIVER \
    HIKARICP_VERSION

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
    MQTT_PORT \
    SCHEDULER_SUPPORT

RUN echo $AMQ_VERSION
RUN echo ${AMQ_VERSION}
RUN apt update
RUN apt install wget vim -y \
    && mkdir -p ${ACTIVEMQ_WORKDIR} \
    && mkdir -p ${CONTAINER_METRICS}
RUN wget https://archive.apache.org/dist/activemq/${AMQ_VERSION}/apache-activemq-${AMQ_VERSION}-bin.tar.gz \
    && wget https://repo1.maven.org/maven2/com/zaxxer/HikariCP/${HIKARICP_VERSION}/HikariCP-${HIKARICP_VERSION}.jar \
    && wget https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRESQL_JDBC_DRIVER}/postgresql-${POSTGRESQL_JDBC_DRIVER}.jar \
    && wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_httpserver/${PROM_EXPORTER_VERSION}/jmx_prometheus_httpserver-${PROM_EXPORTER_VERSION}.jar
RUN tar -xzf apache-activemq-${AMQ_VERSION}-bin.tar.gz -C ${ACTIVEMQ_WORKDIR} \
    && rm \apache-activemq-${AMQ_VERSION}-bin.tar.gz \
    && mv HikariCP-${HIKARICP_VERSION}.jar ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/lib/optional/HikariCP-${HIKARICP_VERSION}.jar \
    && mv postgresql-${POSTGRESQL_JDBC_DRIVER}.jar ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/lib/optional/postgresql-${POSTGRESQL_JDBC_DRIVER}.jar\
    && mv jmx_prometheus_httpserver-${PROM_EXPORTER_VERSION}.jar ${CONTAINER_METRICS}
# users and hosts should go through vars through entrypoint?    

COPY assets/activemq.xml ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
COPY assets/bridges.xml ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/bridges.xml
COPY assets/config.yaml ${CONTAINER_METRICS}/config.yaml
COPY assets/conf $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf

COPY assets/docker-entrypoint.sh /

#For testing purposes only, must be removed!
# COPY assets/security $ACTIVEMQ_WORKDIR/apache-activemq-5.18.3/conf/security

RUN chmod -R 600 ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jmx.access ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jmx.password
RUN chmod 777 /docker-entrypoint.sh

WORKDIR ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/

EXPOSE 8161 61616

ENTRYPOINT ["/docker-entrypoint.sh"]
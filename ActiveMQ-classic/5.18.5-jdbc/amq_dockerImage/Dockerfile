FROM adoptopenjdk/openjdk11-openj9:alpine-jre

ARG AMQ_VERSION \
    POSTGRESQL_JDBC_DRIVER \
    HIKARICP_VERSION

ENV ACTIVEMQ_WORKDIR /opt 

ENV BROKER_NAME \
    DB_HOST \
    DB_USERNAME \
    DB_PASSWORD \
    DB_NAME \
    CREATE_DB_TABLES \
    ACTIVEMQ_ADMIN_PASS \
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

RUN apk add --no-cache --upgrade bash
RUN apk add wget \
    && mkdir -p ${ACTIVEMQ_WORKDIR} \
    && mkdir -p ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/users \
    && mkdir -p ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/groups \
    && mkdir -p ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/ssl
RUN wget https://archive.apache.org/dist/activemq/${AMQ_VERSION}/apache-activemq-${AMQ_VERSION}-bin.tar.gz \
    && wget https://repo1.maven.org/maven2/com/zaxxer/HikariCP/${HIKARICP_VERSION}/HikariCP-${HIKARICP_VERSION}.jar \
    && wget https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRESQL_JDBC_DRIVER}/postgresql-${POSTGRESQL_JDBC_DRIVER}.jar
RUN tar -xzf apache-activemq-${AMQ_VERSION}-bin.tar.gz -C ${ACTIVEMQ_WORKDIR} \
    && rm apache-activemq-${AMQ_VERSION}-bin.tar.gz \
    && mv HikariCP-${HIKARICP_VERSION}.jar ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/lib/optional/HikariCP-${HIKARICP_VERSION}.jar \
    && mv postgresql-${POSTGRESQL_JDBC_DRIVER}.jar ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/lib/optional/postgresql-${POSTGRESQL_JDBC_DRIVER}.jar
RUN mv ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/users.properties ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/users/users.properties \
    && mv ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/groups.properties ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/groups/groups.properties

COPY assets/activemq.xml ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
COPY assets/bridges.xml ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/bridges.xml
COPY assets/conf $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf
COPY assets/monitor_bridges.sh $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/monitor_bridges.sh

COPY assets/docker-entrypoint.sh /

RUN chmod -R 600 ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jmx.access ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jmx.password
RUN addgroup -S activemq && adduser -S activemq -G activemq
RUN chown -R activemq:activemq ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}
RUN chmod 777 /docker-entrypoint.sh
RUN chmod 777 $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/monitor_bridges.sh

WORKDIR ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/

ENTRYPOINT ["/docker-entrypoint.sh"]

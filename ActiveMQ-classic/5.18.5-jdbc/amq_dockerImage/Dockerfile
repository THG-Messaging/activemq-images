FROM alpine/java:22 AS base

ARG AMQ_VERSION
ARG POSTGRESQL_JDBC_DRIVER
ARG HIKARICP_VERSION
ARG JMX_EXPORTER_VERSION

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
    SCHEDULER_SUPPORT \
    AUTH_TYPE

RUN apk add --no-cache --upgrade bash git github-cli python3 py3-pip wget xmlstarlet supervisor util-linux && \
    ln -sf python3 /usr/bin/python && \
    python3 -m venv /opt/pyvenv --system-site-packages && \
    /opt/pyvenv/bin/pip3 install requests flask && \
    mkdir -p \
        /opt/supervisor \
        /opt/jmx_exporter \
        /opt/lbchecker \
        ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/users \
        ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/groups \
        ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/ssl

# Download and extract in a single layer
RUN wget -q https://archive.apache.org/dist/activemq/${AMQ_VERSION}/apache-activemq-${AMQ_VERSION}-bin.tar.gz -O /tmp/activemq.tar.gz && \
    wget -q https://repo1.maven.org/maven2/com/zaxxer/HikariCP/${HIKARICP_VERSION}/HikariCP-${HIKARICP_VERSION}.jar -P ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/lib/optional/ && \
    wget -q https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRESQL_JDBC_DRIVER}/postgresql-${POSTGRESQL_JDBC_DRIVER}.jar -P ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/lib/optional/ && \
    wget -q https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar -P /opt/jmx_exporter/ && \
    tar -xzf /tmp/activemq.tar.gz -C ${ACTIVEMQ_WORKDIR} && \
    rm /tmp/activemq.tar.gz

RUN mv ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/users.properties ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/users/users.properties && \
    mv ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/groups.properties ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/security/groups/groups.properties

COPY assets/activemq.xml ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/activemq.xml
COPY assets/conf/jolokia-access.xml ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jolokia-access.xml
COPY assets/conf $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf
COPY assets/monitor_git.sh $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/monitor_git.sh
COPY assets/monitoring ${ACTIVEMQ_WORKDIR}/jmx_exporter
COPY assets/lbchecker.py /opt/lbchecker/lbchecker.py
COPY assets/supervisord.conf /opt/supervisor/supervisord.conf
COPY assets/docker-entrypoint.sh /

# Combine user and permission settings
RUN addgroup -S activemq && adduser -S activemq -G activemq && \
    chown -R activemq:activemq ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION} && \
    chmod 600 ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jmx.access ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/conf/jmx.password && \
    chmod 777 /docker-entrypoint.sh \
              $ACTIVEMQ_WORKDIR/apache-activemq-${AMQ_VERSION}/conf/monitor_git.sh

WORKDIR ${ACTIVEMQ_WORKDIR}/apache-activemq-${AMQ_VERSION}/

ENTRYPOINT ["/docker-entrypoint.sh"]

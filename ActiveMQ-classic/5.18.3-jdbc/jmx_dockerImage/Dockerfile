FROM adoptopenjdk/openjdk11-openj9:alpine-jre

ARG EXPORTER_VERSION \
    HOSTNAME \
    PORT \
    MONITOR_ROLE_PASS

ENV METRICS_WORKDIR /opt/metrics

RUN apk add wget

RUN mkdir ${METRICS_WORKDIR} \
    && wget https://repo.maven.apache.org/maven2/io/prometheus/jmx/jmx_prometheus_httpserver/${EXPORTER_VERSION}/jmx_prometheus_httpserver-${EXPORTER_VERSION}.jar -P ${METRICS_WORKDIR}

COPY assets/config.yaml ${METRICS_WORKDIR}
COPY assets/docker-entrypoint.sh /

RUN chmod 777 /docker-entrypoint.sh

WORKDIR ${METRICS_WORKDIR}/

ENTRYPOINT ["/docker-entrypoint.sh"]

#!/bin/sh
if [ "$DEBUG" = "true" ] ; then
set -x
else
set +x
fi

sed -i "s/HOSTNAME/${HOSTNAME}/" ${METRICS_WORKDIR}/config.yaml
sed -i "s/PORT/${PORT}/" ${METRICS_WORKDIR}/config.yaml
sed -i "s/MONITOR_ROLE_PASS/${MONITOR_ROLE_PASS}/" ${METRICS_WORKDIR}/config.yaml

java -jar ${METRICS_WORKDIR}/jmx_prometheus_httpserver-${EXPORTER_VERSION}.jar ${SERVICE_PORT} ${METRICS_WORKDIR}/config.yaml

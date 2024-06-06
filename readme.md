ActiveMQ Classic docker images
=====

## .env file variables sample
Name     | Value
---------|------------
BROKER_NAME | localhost
DB_HOST | postgres
DB_USERNAME | postgres
DB_PASSWORD | mysecretpassword
DB_NAME | postgres
CREATE_DB_TABLES | false
ACTIVEMQ_ADMIN_PASS | mysecretpassword
METRICS_ENABLED | true
USE_JMX | true
CONTROL_ROLE_PASS | mypassword
MONITOR_ROLE_PASS | mypassword
OPENWIRE_ENABLED | true
OPENWIRE_PORT | 61616
AMQP_ENABLED | false
AMQP_PORT | 11111
STOMP_ENABLED | false
STOMP_PORT | 61613
MQTT_ENABLED | false
MQTT_PORT | 11133
SCHEDULER_SUPPORT | true
DEBUG | true

## versions.env file variables sample
Name     | Value
---------|------------
PROM_EXPORTER_VERSION | 0.20.0
POSTGRESQL_JDBC_DRIVER | 42.7.3
AMQ_VERSION | 5.18.3
HIKARICP_VERSION | 5.1.0

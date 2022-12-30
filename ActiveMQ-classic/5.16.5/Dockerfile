FROM adoptopenjdk/openjdk11-openj9
ENV ACTIVEMQ_WORKDIR /opt
RUN apt-get install wget
RUN mkdir -p $ACTIVEMQ_WORKDIR
RUN https://dlcdn.apache.org/activemq/5.16.5/apache-activemq-5.16.5-bin.tar.gz
RUN tar -xzf apache-activemq-5.16.5-bin.tar.gz -C $ACTIVEMQ_WORKDIR 
WORKDIR /opt/apache-activemq-5.16.5/
EXPOSE 8161
EXPOSE 61616
CMD ["/bin/sh", "-c", "bin/activemq console"]

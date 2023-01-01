FROM adoptopenjdk/openjdk11-openj9
ENV ACTIVEMQ_WORKDIR /opt
RUN apt update
RUN apt install wget
RUN mkdir -p $ACTIVEMQ_WORKDIR
RUN wget https://dlcdn.apache.org/activemq/5.16.5/apache-activemq-5.16.5-bin.tar.gz
RUN tar -xzf apache-activemq-5.16.5-bin.tar.gz -C $ACTIVEMQ_WORKDIR
RUN sed -i '127.0.0.1/0.0.0.0' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty.xml
WORKDIR /opt/apache-activemq-5.16.5/
EXPOSE 8161 61616
CMD ["/bin/sh", "-c", "bin/activemq console"]

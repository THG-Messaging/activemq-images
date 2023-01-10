FROM adoptopenjdk/openjdk11-openj9
ENV ACTIVEMQ_WORKDIR /opt
RUN apt update
RUN apt install wget
RUN mkdir -p $ACTIVEMQ_WORKDIR
RUN wget https://dlcdn.apache.org//activemq/5.17.3/apache-activemq-5.17.3-bin.tar.gz
RUN tar -xzf apache-activemq-5.17.3-bin.tar.gz -C $ACTIVEMQ_WORKDIR
RUN sed -i 's/127.0.0.1/0.0.0.0/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.17.3/conf/jetty.xml
RUN sed -i 's/admin: admin, admin/admin: admin, gaidys/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
RUN sed -i 's/user: user, user/d' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
WORKDIR /opt/apache-activemq-5.17.3/
EXPOSE 8161 61616
CMD ["/bin/sh", "-c", "bin/activemq console"]

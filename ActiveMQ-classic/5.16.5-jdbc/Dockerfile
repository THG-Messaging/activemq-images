# @ToDo maybe use Alpine for lightweight?
#FROM ubuntu:18.04 
FROM adoptopenjdk/openjdk11-openj9

ENV ACTIVEMQ_WORKDIR /opt

RUN apt update
RUN apt install wget \
    && apt install vim -y \
# install telnet temporarily  
    && apt install telnet -y
RUN mkdir -p $ACTIVEMQ_WORKDIR
RUN wget https://dlcdn.apache.org/activemq/5.16.5/apache-activemq-5.16.5-bin.tar.gz \
    && wget https://repo1.maven.org/maven2/com/zaxxer/HikariCP/5.0.1/HikariCP-5.0.1.jar
RUN tar -xzf apache-activemq-5.16.5-bin.tar.gz -C $ACTIVEMQ_WORKDIR \
    && mv HikariCP-5.0.1.jar $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/lib/optional/HikariCP-5.0.1.jar

# users and hosts should go through vars?    
RUN sed -i 's/127.0.0.1/0.0.0.0/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty.xml
RUN sed -i 's/admin: admin, admin/admin: admin, gaidys/g' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties
RUN sed -i '/user: user, user/d' $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/jetty-realm.properties

COPY assets/activemq.xml $ACTIVEMQ_WORKDIR/apache-activemq-5.16.5/conf/activemq.xml

WORKDIR /opt/apache-activemq-5.16.5/

EXPOSE 8161 61616
CMD ["/bin/sh", "-c", "bin/activemq console"]

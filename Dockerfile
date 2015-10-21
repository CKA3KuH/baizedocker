# baizedocker

FROM ubuntu:14.04
MAINTAINER Ricardo de Castro (rcastro@gmv.com)

RUN locale-gen es_ES.UTF-8
ENV LANG es_ES.UTF-8
ENV LANGUAGE es_ES:es
ENV LC_ALL es_ES.UTF-8

ENV PROXYHOST 192.168.131.13
ENV PROXYPORT 80

ENV http_proxy $PROXYHOST:$PROXYPORT
ENV https_proxy $PROXYHOST:$PROXYPORT

RUN echo 'Acquire::http::Proxy "http://'$PROXYHOST:$PROXYPORT'";' >> /etc/apt/apt.conf
RUN apt-get update


# INSTALLING SSH
RUN sudo apt-get --quiet -y install openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:screencast' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd


# INSTALLING OPENJDK, POSTGRESQL and TOMCAT
RUN sudo apt-get --quiet -y install openjdk-7-jdk
RUN sudo apt-get --quiet -y install postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3
RUN sudo apt-get --quiet -y install tomcat7-common tomcat7 libtomcat7-java
RUN sudo apt-get --quiet -y install inotify-tools inotify-tools

# MOVING RESOURCES
COPY resources/ness.war /var/lib/tomcat7/webapps/ness.war
COPY resources/baize_dump.sql /tmp/baize_dump.sql
COPY resources/postgresql-9.4-1204.jdbc41.jar /usr/share/tomcat7/lib/postgresql-9.4-1204.jdbc41.jar
#RUN mkdir /var/lib/tomcat7/temp

# CREATE USER, DATABASE, ETC
USER postgres
RUN /etc/init.d/postgresql start \
        && /usr/bin/psql --command "ALTER USER postgres WITH PASSWORD 'b4iz3';" \
        && createdb -O postgres baize
RUN /etc/init.d/postgresql start \
        && sleep 20 \
        && /usr/bin/psql baize < /tmp/baize_dump.sql


USER root
ENV TOMCAT_USER tomcat7
ENV CATALINA_HOME /usr/share/tomcat7
ENV CATALINA_BASE /var/lib/tomcat7
ENV CATALINA_TMPDIR /usr/share/tomcat7/temp
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
ENV JRE_HOME /usr/lib/jvm/java-7-openjdk-amd64
ENV CATALINA_PID /var/run/tomcat7.pid
RUN mkdir $CATALINA_TMPDIR
RUN echo "#!/bin/bash" > $CATALINA_HOME/bin/setenv.sh
RUN set | sed -n -e /^CATALINA.*/p -e /^JRE_.*/p -e /^JAVA_.*/p -e /^LOGGING.*/p -e /^JPDA.*/p | sed "s/\(.*\)/export \1/" >> $CATALINA_HOME/bin/setenv.sh
RUN chmod 755 $CATALINA_HOME/bin/setenv.sh
RUN chown $TOMCAT_USER:$TOMCAT_USER $CATALINA_HOME/bin/setenv.sh

RUN touch $CATALINA_PID $CATALINA_BASE/logs/catalina.out
RUN chown $TOMCAT_USER:$TOMCAT_USER $CATALINA_PID $CATALINA_BASE/logs/catalina.out

EXPOSE 22
EXPOSE 5432
EXPOSE 8080
CMD service postgresql start && sleep 20 && /usr/share/tomcat7/bin/catalina.sh start && /usr/sbin/sshd -D

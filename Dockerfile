FROM tomcat:9-jdk8
MAINTAINER Grant Emsley <grant@emsley.ca> 

ENV JASPERSERVER_VERSION 7.5.0

# Set defaults for SMTP service - using the same ones in jasperserver
ENV SMTP_HOST mail.example.com
ENV SMTP_EMAIL admin@example.com
ENV SMTP_USERNAME admin
ENV SMTP_PASSWORD password
ENV SMTP_PORT 25
ENV URL http://localhost:8080

# Execute all in one layer so that it keeps the image as small as possible
RUN wget "https://sourceforge.net/projects/jasperserver/files/JasperServer/JasperReports%20Server%20Community%20edition%20${JASPERSERVER_VERSION}/TIB_js-jrs-cp_${JASPERSERVER_VERSION}_bin.zip/download" \
         -O /tmp/jasperserver.zip  && \
    unzip /tmp/jasperserver.zip -d /usr/src/ && \
    rm /tmp/jasperserver.zip && \
    mv /usr/src/jasperreports-server-cp-${JASPERSERVER_VERSION}-bin /usr/src/jasperreports-server && \
    rm -r /usr/src/jasperreports-server/samples

# To speed up local testing
# Download manually the jasperreport server release to working dir
# Uncomment ADD & RUN commands below and comment out above RUN command
# ADD TIB_js-jrs-cp_${JASPERSERVER_VERSION}_bin.zip /tmp/jasperserver.zip
# RUN unzip /tmp/jasperserver.zip -d /usr/src/ && \
#    rm /tmp/jasperserver.zip && \
#    mv /usr/src/jasperreports-server-cp-$JASPERSERVER_VERSION-bin /usr/src/jasperreports-server && \
#    rm -r /usr/src/jasperreports-server/samples

# Used to wait for the database to start before connecting to it
# This script is from https://github.com/vishnubob/wait-for-it
# as recommended by https://docs.docker.com/compose/startup-order/

# Add files for the WebServiceDataSource plugin
RUN wget https://community.jaspersoft.com/sites/default/files/releases/jaspersoft_webserviceds_v1.5.zip -O /tmp/webserviceds.zip && \
    unzip /tmp/webserviceds.zip -d /tmp && \
    mkdir -p /usr/src/webservice/WEB-INF && \
    cp -rfv /tmp/JRS/WEB-INF/* /usr/src/webservice/WEB-INF && \
    sed -i 's/queryLanguagesPro/queryLanguagesCe/g' /usr/src/webservice/WEB-INF/applicationContext-WebServiceDataSource.xml && \
    rm -rf /tmp/*

# Add MS SQL JDBC driver
RUN wget https://download.microsoft.com/download/4/0/8/40815588-bef6-4715-bde9-baace8726c2a/sqljdbc_8.2.0.0_enu.tar.gz -O /tmp/mssql.tgz && \
    tar zxvf /tmp/mssql.tgz -C /tmp && \
    cp /tmp/sqljdbc_8.2/enu/mssql-jdbc-8.2.0.jre8.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/app-srv-jdbc-drivers/mssql-jdbc-8.2.0.jre8.jar && \
    rm -rf /tmp/*

ADD wait-for-it.sh /wait-for-it.sh

# Used to bootstrap JasperServer the first time it runs and start Tomcat each
ADD entrypoint.sh /entrypoint.sh
ADD .do_deploy_jasperserver /.do_deploy_jasperserver

#Execute all in one layer so that it keeps the image as small as possible
RUN chmod a+x /entrypoint.sh && \
    chmod a+x /wait-for-it.sh

# This volume allows JasperServer export zip files to be automatically imported when bootstrapping
VOLUME ["/jasperserver-import"]
VOLUME ["/config"]

# Make keystore files be stored in config
ENV ks /config/keystore
ENV ksp /config/keystore

# By default, JasperReports Server only comes with Postgres & MariaDB drivers
# Copy over other JBDC drivers the deploy-jdbc-jar ant task will put it in right location
ADD drivers/db2jcc4-no-pdq-in-manifest.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/app-srv-jdbc-drivers/db2jcc4.jar
ADD drivers/mysql-connector-java-8.0.19.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/app-srv-jdbc-drivers/mysql-connector-java-8.0.19.jar

# Copy web.xml with cross-domain enable
ADD web.xml /usr/local/tomcat/conf/

# Use the minimum recommended settings to start-up
# as per http://community.jaspersoft.com/documentation/jasperreports-server-install-guide/v561/setting-jvm-options-application-servers
ENV JAVA_OPTS="-Xms1024m -Xmx2048m -XX:PermSize=32m -XX:MaxPermSize=512m -Xss2m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled"

# Wait for DB to start-up, start up JasperServer and bootstrap if required
ENTRYPOINT ["/entrypoint.sh"]

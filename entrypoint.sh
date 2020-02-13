#!/bin/bash
set -e


# Make sure config directories exist
mkdir -p /config/WEB-INF

# wait upto 30 seconds for the database to start before connecting
/wait-for-it.sh $DB_HOST:$DB_PORT -t 30

# If this is a fresh container, deploy jasperserver
# If /config/db_is_configured exists, skip the steps for adding things to the database
if [ -f "/.do_deploy_jasperserver" ]; then
    pushd /usr/src/jasperreports-server/buildomatic
    
    # Use provided configuration templates
    # Note: only works for Postgres or MySQL
    cp sample_conf/${DB_TYPE}_master.properties default_master.properties
    
    # tell the bootstrap script where to deploy the war file to
    sed -i -e "s|^appServerDir.*$|appServerDir = $CATALINA_HOME|g" default_master.properties
    
    # set all the database settings
    sed -i -e "s|^dbHost.*$|dbHost=$DB_HOST|g; s|^dbPort.*$|dbPort=$DB_PORT|g; s|^dbUsername.*$|dbUsername=$DB_USER|g; s|^dbPassword.*$|dbPassword=$DB_PASSWORD|g" default_master.properties
    
    # rename the application war so that it can be served as the default tomcat web application
    sed -i -e "s|^# webAppNameCE.*$|webAppNameCE = ROOT|g" default_master.properties

    # Check if we need to configure the database
    if [ ! -f "/config/db_is_configured" ]; then
        ./js-ant create-js-db || true #create database and skip it if database already exists
        ./js-ant init-js-db-ce 
        ./js-ant import-minimal-ce
        touch /config/db_is_configured
    fi

    # Deploy the webapp
    ./js-ant deploy-webapp-ce

    # bootstrap was successful, delete file so we don't bootstrap on subsequent restarts
    rm /.do_deploy_jasperserver
    
    # Add WebServiceDataSource plugin
    cp -rfv /usr/src/webservice/WEB-INF/* /usr/local/tomcat/webapps/ROOT/WEB-INF/

    # Only import the files if the database hasn't previously been configured
    if [ ! -f "/config/db_is_configured" ]; then
        # import any export zip files from another JasperServer
        shopt -s nullglob # handle case if no zip files found
        IMPORT_FILES=/jasperserver-import/*.zip
        for f in $IMPORT_FILES
        do
          echo "Importing $f..."
          ./js-import.sh --input-zip $f
        done

        popd
    fi

    # Done deploying fresh container
fi

# Update SMTP configuration for scheduler
sed -i -e "s|^report.scheduler.mail.sender.host.*$|report.scheduler.mail.sender.host=$SMTP_HOST|g" /usr/local/tomcat/webapps/ROOT/WEB-INF/js.quartz.properties
sed -i -e "s|^report.scheduler.mail.sender.username.*$|report.scheduler.mail.sender.username=$SMTP_USERNAME|g" /usr/local/tomcat/webapps/ROOT/WEB-INF/js.quartz.properties
sed -i -e "s|^report.scheduler.mail.sender.password.*$|report.scheduler.mail.sender.password=$SMTP_PASSWORD|g" /usr/local/tomcat/webapps/ROOT/WEB-INF/js.quartz.properties
sed -i -e "s|^report.scheduler.mail.sender.from.*$|report.scheduler.mail.sender.from=$SMTP_EMAIL|g" /usr/local/tomcat/webapps/ROOT/WEB-INF/js.quartz.properties
sed -i -e "s|^report.scheduler.mail.sender.port.*$|report.scheduler.mail.sender.port=$SMTP_PORT|g" /usr/local/tomcat/webapps/ROOT/WEB-INF/js.quartz.properties
sed -i -e "s|^report.scheduler.web.deployment.uri.*$|report.scheduler.web.deployment.uri=$URL|g" /usr/local/tomcat/webapps/ROOT/WEB-INF/js.quartz.properties



# Update configuation files from the /config volume - mapping them directly breaks buildomatic, so we just copy them every time after everything else is configured
cp -rfv /config/WEB-INF/* /usr/local/tomcat/webapps/ROOT/WEB-INF/ || true

# run Tomcat to start JasperServer webapp
catalina.sh run

# JasperReports Server CE Edition Docker Container

The Docker Image aims to quickly get up-and-running a JasperReports Server for a development environment.
Originally based on retrievercommunications/docker-jasperserver, this docker container has been updated and modified to add more control over JasperReports Server configuration.

[![](https://images.microbadger.com/badges/image/grantemsley/jasperserver.svg)](https://microbadger.com/images/grantemsley/jasperserver "Get your own image badge on microbadger.com")

## Login to JasperReports Web

1. Go to URL http://${dockerHost}:8080/
2. Login using credentials: jasperadmin/jasperadmin


## Image Features
This image includes:
* JasperServer CE Edition version 7.5.0
* IBM DB2 JDBC driver version 4.19.26, Note: this jar had to be modified as per [exception-in-db2-jcc-driver-under-tomcat8](https://developer.ibm.com/answers/questions/308105/exception-in-db2-jcc-driver-under-tomcat8.html).
* MySQL JDBC driver version 5.1.44
* A volume called '/import' that allows automatic importing of export zip files from another JasperReports Server
* Waits for the database to start before connecting to it using [wait-for-it](https://github.com/vishnubob/wait-for-it) as recommended by [docker-compose documentation](https://docs.docker.com/compose/startup-order/).
* [Web Service Data Source plugin](https://community.jaspersoft.com/project/web-service-data-source) contributed by [@chiavegatto](https://github.com/chiavegatto)
* Config volume for storing additional settings and keystore keys

## Environment Variables
* DB_TYPE - the type of database deploying to.  Typically use 'mysql'
* DB_HOST, DB_PORT, DB_USER, DB_PASSWORD - database configuration
* SMTP_HOST, SMTP_PORT - mail server address and port
* SMTP_EMAIL - email address used as from address when jasperserver sends emails
* SMTP_USERNAME, SMTP_PASSWORD - credentials for SMTP server
* URL - the full URL used to access jasperreports - this is used when emails are sent out with links to the server
* DISABLE_HEARTBEAT - set to 'true' to stop prompting to opt in for heartbeat ever time the container is rebuilt

## Files and Paths

There are two volumes used:
* /jasperserver-import - export files placed here get imported into jasperserver when it is first deployed
* /config - configuration data is stored here

Important things under /config:
* /config/db_is_configured - this file is created the first time the container starts up. If the file exists, it won't try to redeploy all the initial database settings and import data again.
* /config/keystore - encryption keys for the server are created and stored here (two hidden files, .jrsks and .jrsksp). These files are required for the server to operate, and to read any exported data. See the [JasperServer 7.5.0 security guide](https://docs.tibco.com/pub/js-jss/7.5.0/doc/pdf/TIB_js-jrs_7.5_Security-Guide.pdf) for more details about handling these files.
* /config/certs - PEM encoded certificate files can be placed here and will be imported into the java cacerts file on startup. Required if using LDAPS authentication.
* /config/WEB-INF - the contents of this folder are copied to the jasperserver WEB-INF folder just before it is launched on each start. You can place any customized configuration files for things like external authentication here. You can also add additional jar libraries to /config/WEB-INF/lib to be loaded by jasperserver.


## Start the Container

### Using Command Line

To start the JasperServer container you'll need to pass in 5 environment variables and link it to either a MySQL or Postgres container.

E.g. `docker run -d --name jasperserver -e DB_TYPE=mysql -e DB_HOST=db -e DB_PORT=3306 -e DB_USER=root -e DB_PASSWORD=mysql -v ./config:/config --link jasperserver_mysql:db -p 8080:8080 retriever/jasperserver`

If you haven't got an existing MySQL or Postgres container then you can easily create one:
`docker run -d --name jasperserver_mysql -e MYSQL_ROOT_PASSWORD=mysql mysql:5.7`


### Using Docker-compose

To start up the JasperServer and a MySQL container:

* Run `docker-compose up` to run in foreground or
* Run `docker-compose up -d` to run as in daemon mode.

To stop the containers run `docker-compose stop` and `docker-compose start` to restart them.

Note: To install Docker-compose see the [releases page](https://github.com/docker/compose/releases). 



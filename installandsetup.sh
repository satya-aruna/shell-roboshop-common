#!/bin/bash

source ./common.sh

# Takes command line arguments servicename, packagename
INSTALL_SETUP() {

    SERVERNAME=$1
    SERVICENAME=$SERVERNAME
    PKGNAME=""
    VERSION=""
    LABEL=""
   
    VALIDATE_USER

    if [ "$SERVERNAME" = "mongodb" ]; then
        SETUP_REPOFILE "$SERVERNAME" "mongo.repo"
        PKGNAME="mongodb-org"
        SERVICENAME="mongod"
        LABEL="Mongodb Server"   
    elif [ "$SERVERNAME" = "rabbitmq" ]; then
        SETUP_REPOFILE "$SERVERNAME" rabbitmq.repo 
        PKGNAME="rabbitmq-server"
        SERVICENAME="rabbitmq-server" 
        LABEL="RabbitMQ Server"
    elif [ "$SERVERNAME" = "mysql" ]; then
        PKGNAME="mysql-server"
        SERVICENAME="mysqld"
        LABEL="MySQL Server"
    elif [ "$SERVERNAME" = "redis" ]; then
        PKGNAME="redis"
        VERSION=7
        LABEL="Redis Server"
        ENABLE_VERSION "$PKGNAME" "$VERSION"
    elif [[ "$SERVERNAME" = "catalogue" || "$SERVERNAME" = "user" || "$SERVERNAME" = "cart" ]]; then
        PKGNAME="nodejs"
        VERSION=20
        ENABLE_VERSION "$PKGNAME" "$VERSION"
        LABEL="NodeJS"
    elif [ "$SERVERNAME" = "shipping" ]; then
        PKGNAME="maven"
        LABEL="Maven"
    elif [ "$SERVERNAME" = "payment" ]; then
        PKGNAME="python3 gcc python3-devel"
        LABEL="Python"
    elif [ "$SERVERNAME" = "dispatch" ]; then
        PKGNAME="golang"
        LABEL="GOLang"
    elif [ "$SERVERNAME" = "frontend" ]; then
        PKGNAME="nginx"
        VERSION=1.24
        ENABLE_VERSION "$PKGNAME" "$VERSION"
        LABEL="Nginx"
    fi

    INSTALL_PACKAGE "$LABEL" "$PKGNAME"

    if [[ "$PKGNAME" = "nodejs" || "$PKGNAME" =  "maven" || "$PKGNAME" =  "python3 gcc python3-devel" || "$PKGNAME" = "golang" ]]; then
        CREATE_APPUSER
        DOWNLOAD_UNZIPAPP "$SERVICENAME"
        INSTALL_APP "$PKGNAME"
        SETUP_SYSD_SERVICE "$SERVICENAME"
    elif [ "$SERVICENAME" = "frontend" ]; then
        ENABLE_START_SYSCTL "$LABEL" "$PKGNAME"
        DOWNLOAD_UNZIPAPP "$SERVICENAME"
        SERVICENAME="$PKGNAME"
    fi

    if [[ "$SERVICENAME" = "mongod" || "$SERVICENAME" = "redis" || "$SERVICENAME" = "nginx" ]]; then
        MODIFY_CONFIG "$SERVICENAME"
    fi

    ENABLE_START_SYSCTL "$SRVERNAME" "$SERVICENAME"

    if [ "$SERVICENAME" = "catalogue" ]; then
        SETUP_REPOFILE "mongodb" "mongo.repo"
        INSTALL_PACKAGE "Mongodb Client" "mongodb-mongosh"
        if [ $(mongosh --host $MONGODB_HOST --eval 'db.getMongo().getDBNames().indexOf("catalogue")' --quiet) -lt 0 ]; then
            mongosh --host $MONGODB_HOST </app/db/master-data.js &>> $LOGS_FILE
            VALIDATE $? "Loading the catalogue data into MongoDB"
        else
            echo -e "Catalogue database already exists... $Y SKIPPING $N"
        fi
    fi

    if [ "$SERVICENAME" = "mysqld" ]; then
        # Set root password
        mysql_secure_installation --set-root-pass RoboShop@1
        VALIDATE $? "Changing the default root password"
    fi

    if [ "$SERVICENAME" = "shipping" ]; then

        INSTALL_PACKAGE "MySQL Client" "mysql"

        mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWD" < /app/db/schema.sql
        VALIDATE $? "Load Schema in mysql database"

        mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWD" < /app/db/app-user.sql 
        VALIDATE $? "Creating app user in mysql database"

        mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWD" < /app/db/master-data.sql
        VALIDATE $? "Loading the Master data for shipping"

    fi

    if [ "$SERVICENAME" = "rabbitmq-server" ]; then
        # Check if a user named 'roboshop' exists
        rabbitmqctl list_users | grep -q "^roboshop\s"

        # Check exit status: 0 if exists, 1 if not
        if [ $? -eq 0 ]; then
             echo -e "User roboshop exists...$Y SKIPPING $N"
        else
            rabbitmqctl add_user roboshop roboshop123
            VALIDATE $? "Creating rabbitmq application user"

            rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
            VALIDATE $? "Setting permissions to rabbitmq application user"
        fi
    fi
    
    SYSCTL_RESTART "$SRVERNAME" "$SERVICENAME"

}





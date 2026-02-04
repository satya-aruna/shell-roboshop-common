#!/bin/bash

# color codes in Linux, can be enabled with echo -e option
R='\e[31m'
G='\e[32m'
Y='\e[33m'
B='\e[34m'
N='\e[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
USERID=$(id -u) # userid of root user 0, and others non-zero
LOGS_FOLDER="/var/log/shell-roboshop-common"
LOGS_FILE="$LOGS_FOLDER/$0.log"
MONGODB_HOST="mongodb.asadaws2026.online"
MYSQL_HOST="mysql.asadaws2026.online"
MYSQL_USER="root"
MYSQL_PASSWD="RoboShop@1"

mkdir -p $LOGS_FOLDER

VALIDATE_USER() {

    if [ $USERID -ne 0 ]; then
        echo -e "$R Please run this script with root user access $N" | tee -a $LOGS_FILE
        exit 1 # we need to exit with failure exit code
    fi
}

# Validate the status of a command
VALIDATE() {

    if [ $1 -ne 0 ]; then
        echo -e "$(date "+%Y-%m-%d %H:%M:%S") | $2 ...$R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$(date "+%Y-%m-%d %H:%M:%S") | $2 ...$G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}


SETUP_REPOFILE() {

    SERVICE=$1
    REPO_FILE=$2

    cp "$SCRIPT_DIR/$REPO_FILE" "/etc/yum.repos.d/$REPO_FILE"
    VALIDATE $? "Setup $SERVICE repo"
}

ENABLE_VERSION() {

    PKG_NAME=$1
    VER=$2

    dnf module disable "$PKG_NAME" -y &>> $LOGS_FILE
    VALIDATE $? "Disabling $PKG_NAME default version"

    dnf module enable "$PKG_NAME:$VER" -y &>> $LOGS_FILE
    VALIDATE $? "Enabling $PKG_NAME version $VER"
}

INSTALL_PACKAGE() {

    SRVCNAME=$1
    PCK_NAME=$2

    dnf install $PCK_NAME -y &>> $LOGS_FILE
    VALIDATE $? "Installing $SRVCNAME"

}

CREATE_APPUSER() {

    id roboshop &>> $LOGS_FILE
    if [ $? -ne 0 ]; then
        useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop  &>> $LOGS_FILE
        VALIDATE $? "Creating Application User"
    else
        echo -e "Roboshop user already exists...$Y SKIPPING $N" | tee -a $LOGS_FILE
    fi
}

DOWNLOAD_UNZIPAPP() {

    APPNAME=$1

    if [ "$APPNAME" != "frontend" ]; then

        rm -rf /app
        VALIDATE $? "Remove the /app directory if already exists"

        mkdir -p /app 
        VALIDATE $? "Creating Application directory"

        curl -L -o "/tmp/$APPNAME.zip" "https://roboshop-artifacts.s3.amazonaws.com/$APPNAME"-v3.zip &>> $LOGS_FILE
        VALIDATE $? "Downloading Application code to temp directory"

        cd /app
        VALIDATE $? "Go to Application directory"

        unzip "/tmp/$APPNAME.zip"  &>> $LOGS_FILE
        VALIDATE $? "Unzip the application code"
    
    else

        rm -rf /usr/share/nginx/html/* 
        VALIDATE $? "Remove the default contentent of web server"

        curl -o "/tmp/$APPNAME.zip" "https://roboshop-artifacts.s3.amazonaws.com/$APPNAME-v3.zip" &>> $LOGS_FILE
        VALIDATE $? "Download the frontend content"

        cd /usr/share/nginx/html 
        VALIDATE $? "Go to html folder"

        unzip "/tmp/$APPNAME.zip" &>> $LOGS_FILE
        VALIDATE $? "Unzip the frontend content"
    fi
}

INSTALL_APP() {

    PKG="$1"

    if [ "$PKG" = "nodejs" ]; then
        npm install &>> "$LOGS_FILE"
        VALIDATE $? "Install dependencies"

    elif [ "$PKG" = "maven" ]; then
        mvn clean package &>> "$LOGS_FILE"
        VALIDATE $? "Download dependencies and build the application"

        mv "target/shipping-1.0.jar" "shipping.jar"
        VALIDATE $? "Moving the target application to parent folder"

    elif [ "$PKG" = "python3 gcc python3-devel" ]; then
        pip3 install -r "requirements.txt" &>> "$LOGS_FILE"
        VALIDATE $? "Download and install dependencies"

    elif [ "$PKG" = "golang" ]; then
        go mod init dispatch &>> "$LOGS_FILE"
        VALIDATE $? "Initializing the dispatch module"

        go get &>> "$LOGS_FILE"
        VALIDATE $? "Download and install dependencies"

        go build &>> "$LOGS_FILE"
        VALIDATE $? "Build the dispatch application"
    fi
}


SETUP_SYSD_SERVICE() {

    SVCNAME=$1

    cp "$SCRIPT_DIR/$SVCNAME.service" "/etc/systemd/system/$SVCNAME.service"
    VALIDATE $? "Setup Systemd $SVCNAME service for systemctl"

    systemctl daemon-reload
    VALIDATE $? "Reload the newly created systemd $SVCNAME service"
}

ENABLE_START_SYSCTL() {

    SRVR=$1
    SNAME=$2

    systemctl enable "$SNAME" &>> $LOGS_FILE
    VALIDATE $? "Enable $SRVR service"

    systemctl start "$SNAME"
    VALIDATE $? "Start $SRVR service"
}

MODIFY_CONFIG() {

    SN=$1

    if [ "$SN" = "mongod" ]; then
        sed -i 's/127.0.0.1/0.0.0.0/g' "/etc/$SN.conf" 
        VALIDATE $? "$SN.conf change to allow all connections"
    elif [ "$SN" = "redis" ]; then
        sed -i -e 's/127.0.0.1/0.0.0.0/g' -e '/protected-mode/ c protected-mode no' "/etc/$SN/$SN.conf"
        VALIDATE $? "$SN.conf change to allow all connections and disable protected-mode"
    elif [ "$SN" = "nginx" ]; then
        cp "$SCRIPT_DIR/$SN.conf" "/etc/$SN/$SN.conf"
        VALIDATE $? "Create $SN Reverse Proxy Configuration"
    fi
}

SYSCTL_RESTART() {

    SRNM=$1
    SNM=$2

    systemctl restart "$SNM" 
    VALIDATE $? "Restart $SRNM after config changes"
}


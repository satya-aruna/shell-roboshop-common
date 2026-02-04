#!/bin/bash

NAME=Aruna

GENDER="Female"

echo $NAME

echo "$NAME"

echo $GENDER

echo "$GENDER"
 
SHOW_OUTPUT() {
    echo "Name : $1"
    echo "Gender : $2"
}

SHOW_OUTPUT $NAME $GENDER



#!/usr/bin/env sh

KEYPATH=".sekrets"
KEYNAME="deploy-aws"

openssl genrsa -out "$KEYPATH/aws.pem" 4096
openssl rsa -in "$KEYPATH/aws.pem" -pubout > "$KEYPATH/aws.pub"
chmod 400 "$KEYPATH/aws.pem"

aws ec2 import-key-pair \
  --key-name $KEYNAME \
  --public-key-material "$(grep -v PUBLIC $KEYPATH/aws.pub | tr -d '\n')"

cp $KEYPATH/aws.pem $HOME/.ssh/$KEYNAME.pem
cp $KEYPATH/aws.pub $HOME/.ssh/$KEYNAME.pub

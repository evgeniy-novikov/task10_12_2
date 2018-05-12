#!/bin/bash

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $dir
source "$dir/config"
mkdir -p $dir/etc/nginx/
mkdir -p $dir/etc/ssl/certs

################ install docker and other ###########
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update && apt-get install -y docker-ce docker-compose
####################################################
################# CERT CREATE CONFIG ##########################
echo "
[ req ]
default_bits                = 4096
default_keyfile             = privkey.pem
distinguished_name          = req_distinguished_name
req_extensions              = v3_req

[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
countryName_default         = UK
stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Wales
localityName                = Locality Name (eg, city)
localityName_default        = Cardiff
organizationName            = Organization Name (eg, company)
organizationName_default    = Example UK
commonName                  = Common Name (eg, YOUR name)
commonName_default          = one.test.app.example.net
commonName_max              = 64

[ v3_req ]
basicConstraints            = CA:FALSE
keyUsage                    = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName              = @alt_names

[alt_names]
IP.1  = $EXTERNAL_IP
DNS.1 = $HOST_NAME" > /usr/lib/ssl/openssl-san.cnf

########## SSL ######
openssl genrsa -out $dir/etc/ssl/certs/root-ca.key 4096
openssl req -x509 -new -key $dir/etc/ssl/certs/root-ca.key -days 365 -out $dir/etc/ssl/certs/root-ca.crt -subj "/C=UA/L=Kharkov/O=HOME/OU=IT/CN=$HOST_NAME"
openssl genrsa -out $dir/etc/ssl/certs/web.key 4096
openssl req -new -key $dir/etc/ssl/certs/web.key -out $dir/etc/ssl/certs/web.csr -config /usr/lib/ssl/openssl-san.cnf -subj "/C=UA/L=Kharkov/O=HOME/OU=IT/CN=$HOST_NAME"
openssl x509 -req -in $dir/etc/ssl/certs/web.csr -CA $dir/etc/ssl/certs/root-ca.crt  -CAkey $dir/etc/ssl/certs/root-ca.key -CAcreateserial -out $dir/etc/ssl/certs/web.crt -days 365 -extensions v3_req -extfile /usr/lib/ssl/openssl-san.cnf
cat $dir/etc/ssl/certs/root-ca.crt >> $dir/etc/ssl/certs/web.crt
###############################################################

################## NGINX CONF #################################
echo "
server {
listen  $NGINX_PORT;
ssl on;
ssl_certificate /etc/ssl/certs/web.crt;
ssl_certificate_key /etc/ssl/certs/web.key;
 location / {
    	    proxy_pass http://apache;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
    }
} " >> $dir/etc/nginx/nginx.conf

################# YML CONFIG ##################################
echo "version: '2'
services:
  nginx:
    image: $NGINX_IMAGE
    ports:
      - '$NGINX_PORT:$NGINX_PORT'
    volumes:
      - $dir/etc/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - $NGINX_LOG_DIR:/var/log/nginx
      - $dir/etc/ssl/certs:/etc/ssl/certs/nginx
  apache:
    image: $APACHE_IMAGE" > docker-compose.yml

docker-compose up -d
docker-compose ps


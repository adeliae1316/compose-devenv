#!/usr/bin/env bash

CURRENT_DIR=$(cd $(dirname $0); pwd)

set -o allexport
source "${CURRENT_DIR}"/.env
set +o allexport

# Keycloak configuration (pre launch)

python3 "${CURRENT_DIR}"/keycloak/generate_realm.py

# Launch LDAP and Keycloak

docker-compose \
    -f "${CURRENT_DIR}"/docker-compose.auth.yaml \
    up --detach

docker run --net host -it jwilder/dockerize \
    -wait-retry-interval 5s \
    -wait tcp://"${_HOSTNAME}:${_KEYCLOAK_HTTPS_PORT}" \
    -timeout 60s

# LDAP configuration

docker exec -it openldap ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/init.ldif -c

# Keycloak configuration (post launch)

docker exec -it keycloak bash -c '/opt/keycloak/bin/kcadm.sh config credentials --realm master --server http://localhost:8080 --user admin --password admin && /opt/keycloak/bin/kcadm.sh create --target-realm local user-storage/$(/opt/keycloak/bin/kcadm.sh get --target-realm local components --query name=ldap --fields id | grep id | sed -e "s/\"//g" -e "s/\s*id\ :\ //g")/sync?action=triggerFullSync'

# GitLab and Growi configuration for Keycloak

_KEYCLOAK_URL="https://${_HOSTNAME}:${_KEYCLOAK_HTTPS_PORT}"

curl --capath "${CURRENT_DIR}"/certs/rootCA.pem --silent "${_KEYCLOAK_URL}"/realms/local/protocol/saml/descriptor \
    | sed -e 's/^.*<ds:X509Certificate>\(.*\)<\/ds:X509Certificate>.*$/\1/g' \
    | printf -- "-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n" $(cat) \
    | openssl x509 -sha1 -fingerprint -noout \
    | sed -e 's/^.*sha1 Fingerprint=\(.*\)/\1/g' \
    | printf -- "_KEYCLOAK_GITL_FP='%s'\n" $(cat) >> .env

curl --capath "${CURRENT_DIR}"/certs/rootCA.pem --silent "${_KEYCLOAK_URL}"/realms/local/protocol/saml/descriptor \
    | sed -e 's/^.*<ds:X509Certificate>\(.*\)<\/ds:X509Certificate>.*$/\1/g' \
    | printf -- "_KEYCLOAK_WIKI_PEM='%s'\n" $(cat) >> .env

exit 0

# WIP

docker-compose \
    -f "${CURRENT_DIR}"/docker-compose.minio.yaml \
    -f "${CURRENT_DIR}"/docker-compose.growi.yaml \
    -f "${CURRENT_DIR}"/docker-compose.gitlab.yaml \
    up --detach

docker run -p 9000:9000 -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

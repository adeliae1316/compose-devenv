#!/usr/bin/env bash

trap 'exit 1' SIGINT

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

docker run --network internal_sso -it jwilder/dockerize \
    -wait-retry-interval 5s \
    -wait tcp://keycloak:8443 \
    -timeout 60s

# LDAP configuration

docker exec -it openldap ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/init.ldif -c

# Keycloak configuration (post launch)

docker exec -it keycloak \
    bash -c '/opt/keycloak/bin/kcadm.sh config credentials --realm master --server http://localhost:8080 --user admin --password admin && /opt/keycloak/bin/kcadm.sh create --target-realm local user-storage/$(/opt/keycloak/bin/kcadm.sh get --target-realm local components --query name=ldap --fields id | grep id | sed -e "s/\"//g" -e "s/\s*id\ :\ //g")/sync?action=triggerFullSync'

# GitLab and Growi configuration for Keycloak

sed -e '/^_KEYCLOAK_GITL_FP/d' -e '/^_KEYCLOAK_WIKI_PEM/d' -i "${CURRENT_DIR}"/.env

_KEYCLOAK_URL="https://${_HOSTNAME}:${_KEYCLOAK_HTTPS_PORT}"

curl --capath "${CURRENT_DIR}"/certs/rootCA.pem --silent "${_KEYCLOAK_URL}"/realms/local/protocol/saml/descriptor \
    | sed -e 's/^.*<ds:X509Certificate>\(.*\)<\/ds:X509Certificate>.*$/\1/g' \
    | printf -- "-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n" $(cat) \
    | openssl x509 -sha1 -fingerprint -noout \
    | sed -e 's/^.*sha1 Fingerprint=\(.*\)/\1/g' \
    | printf -- "_KEYCLOAK_GITL_FP='%s'\n" $(cat) >> "${CURRENT_DIR}"/.env

curl --capath "${CURRENT_DIR}"/certs/rootCA.pem --silent "${_KEYCLOAK_URL}"/realms/local/protocol/saml/descriptor \
    | sed -e 's/^.*<ds:X509Certificate>\(.*\)<\/ds:X509Certificate>.*$/\1/g' \
    | printf -- "_KEYCLOAK_WIKI_PEM='%s'\n" $(cat) >> "${CURRENT_DIR}"/.env

# Launch minio

docker-compose \
    -f "${CURRENT_DIR}"/docker-compose.minio.yaml \
    up --detach

docker run --network internal_minio -it jwilder/dockerize \
    -wait-retry-interval 5s \
    -wait tcp://minio1:9000 -wait tcp://minio2:9000 -wait tcp://minio3:9000 -wait tcp://minio4:9000 \
    -wait tcp://minio1:9001 -wait tcp://minio2:9001 -wait tcp://minio3:9001 -wait tcp://minio4:9001 \
    -timeout 60s

# MinIO configuration

docker run --network internal_minio -it \
    --entrypoint=/bin/bash minio/mc:latest \
    -c "/usr/bin/mc config host add minio http://minio1:9000 minioadmin minioadmin-pswd && /usr/bin/mc mb --ignore-existing minio/growi"

# Launch growi

docker-compose \
    -f "${CURRENT_DIR}"/docker-compose.growi.yaml \
    up --build --detach

docker run --network internal_wiki -it jwilder/dockerize \
    -wait-retry-interval 10s \
    -wait tcp://growi:3000 \
    -wait tcp://drawio:8080 \
    -wait tcp://hackmd:3000 \
    -wait tcp://elasticsearch:9200 \
    -timeout 120s

# logout ps

echo
echo

docker-compose \
    -f "${CURRENT_DIR}"/docker-compose.auth.yaml \
    -f "${CURRENT_DIR}"/docker-compose.minio.yaml \
    -f "${CURRENT_DIR}"/docker-compose.growi.yaml \
    -f "${CURRENT_DIR}"/docker-compose.gitlab.yaml \
    ps

exit 0

# WIP

docker-compose \
    -f "${CURRENT_DIR}"/docker-compose.gitlab.yaml \
    up --detach

docker run -p 9000:9000 -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

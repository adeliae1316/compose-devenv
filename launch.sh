#!/usr/bin/env bash

trap 'exit 1' SIGINT

CURRENT_DIR=$(cd $(dirname $0); pwd)

set -e

set -o allexport
source "${CURRENT_DIR}/.env"
set +o allexport

# Overview

echo
echo \# launch developer tools
echo

echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Generate certs

if [ ! -d "${CURRENT_DIR}/mkcert/certs" ]; then
    echo Generate certs
    echo
    (
        "${CURRENT_DIR}/mkcert.sh"
    )
fi

echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Keycloak configuration (pre launch)

echo Generate Keycloak config
echo

docker run \
    --rm \
    --workdir '/work' \
    --env _UID=${UID} \
    --volume "${CURRENT_DIR}/keycloak:/work" \
    --volume "${CURRENT_DIR}/.env:/work/.env:ro" \
    python:latest \
    bash -c 'python -m pip install python-dotenv &> /dev/null \
            && python generate_realm.py \
            && chown ${_UID}:${_UID} import.json'

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Launch LDAP and Keycloak

echo Start LDAP and Keycloak
echo

docker compose \
    -f "${CURRENT_DIR}"/docker-compose.auth.yaml \
    up --detach --wait

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# LDAP configuration

echo Configure LDAP
echo

docker exec -it openldap ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/init.ldif -c &> /dev/null

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Keycloak configuration (post launch)

echo Configure Keycloak
echo

docker exec -it keycloak \
    bash -c '/opt/keycloak/bin/kcadm.sh config credentials \
            --realm master --server http://localhost:8080 \
            --user admin --password admin \
            && /opt/keycloak/bin/kcadm.sh create --target-realm local \
            user-storage/$(/opt/keycloak/bin/kcadm.sh get --target-realm local components --query name=ldap --fields id | grep id | sed -e "s/\"//g" -e "s/\s*id\ :\ //g")/sync?action=triggerFullSync'

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# GitLab and Growi configuration for Keycloak

echo Get keycloak certs
echo

sed -e '/^_KEYCLOAK_GITL_FP/d' -e '/^_KEYCLOAK_WIKI_PEM/d' -i "${CURRENT_DIR}"/.env

_KEYCLOAK_URL="https://${_HOSTNAME}:${_KEYCLOAK_HTTPS_PORT}"

curl --cacert "${CURRENT_DIR}"/mkcert/certs/root.crt --silent "${_KEYCLOAK_URL}"/realms/local/protocol/saml/descriptor \
    | sed -e 's/^.*<ds:X509Certificate>\(.*\)<\/ds:X509Certificate>.*$/\1/g' \
    | printf -- "-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n" $(cat) \
    | openssl x509 -sha1 -fingerprint -noout \
    | sed -e 's/^.*sha1 Fingerprint=\(.*\)/\1/g' \
    | printf -- "_KEYCLOAK_GITL_FP='%s'\n" $(cat) >> "${CURRENT_DIR}"/.env

curl --cacert "${CURRENT_DIR}"/mkcert/certs/root.crt --silent "${_KEYCLOAK_URL}"/realms/local/protocol/saml/descriptor \
    | sed -e 's/^.*<ds:X509Certificate>\(.*\)<\/ds:X509Certificate>.*$/\1/g' \
    | printf -- "_KEYCLOAK_WIKI_PEM='%s'\n" $(cat) >> "${CURRENT_DIR}"/.env

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Launch MinIO

echo Start MinIO
echo

docker compose \
    -f "${CURRENT_DIR}"/docker-compose.minio.yaml \
    up --detach --wait

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# MinIO configuration

echo Configure MinIO
echo

docker run --rm --network internal_minio -it \
    --entrypoint=/bin/bash minio/mc:latest \
    -c '/usr/bin/mc config host add minio http://minio1:9000 minioadmin minioadmin-pswd \
        && /usr/bin/mc mb --ignore-existing minio/growi'

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Launch Growi

if [ "true" != "${SKIP_GROWI}" ]; then

    echo Start Growi
    echo

    docker compose \
        -f "${CURRENT_DIR}"/docker-compose.growi.yaml \
        up --build --detach # --wait

    # --wait option cannot detect connection well. So wait with dockerize.
    docker run --rm --network internal_wiki -it jwilder/dockerize \
        -wait-retry-interval 20s \
        -wait tcp://growi:3000 \
        -wait tcp://drawio:8080 \
        -wait tcp://hackmd:3000 \
        -wait tcp://elasticsearch:9200 \
        -timeout 600s

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

fi

# Launch GitLab

if [ "true" != "${SKIP_GITLAB}" ]; then

    echo Start GitLab
    echo

    docker compose \
        -f "${CURRENT_DIR}"/docker-compose.gitlab.yaml \
        up --detach # --wait

    # --wait option cannot detect connection well. So wait with dockerize.
    docker run --rm --network internal_git -it jwilder/dockerize \
        -wait-retry-interval 20s \
        -wait tcp://gitlab:443 \
        -timeout 600s

echo
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

fi

exit 0

docker run --rm -p 9000:9000 -p 9443:9443 \
    --name portainer \
    --restart=unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

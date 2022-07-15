#!/usr/bin/env bash

CURRENT_DIR=$(cd $(dirname $0); pwd)

set -o allexport
source "${CURRENT_DIR}"/.env
set +o allexport

# reduction of build context submission
cat "${CURRENT_DIR}/mkcert/Dockerfile" | docker build -t mkcert -

docker run --rm \
    --env _UID=${UID} --env _USER=${USER} \
    --env CA_NAME="${_LDAP_ORGANISATION} self-signed CA" \
    --env CERT_NAME="${_HOSTNAME}" \
    -v "${CURRENT_DIR}/mkcert/rootcerts:/home/${USER}/.local/share/mkcert" \
    -v "${CURRENT_DIR}/mkcert/usercerts:/home/${USER}/certificates" \
    -v "${CURRENT_DIR}/mkcert/useradd.sh:/tmp/entrypoint.sh:ro" \
    --init --interactive --tty \
    --entrypoint /tmp/entrypoint.sh \
    --workdir /home/${USER}/certificates \
    mkcert \
    bash -c 'sudo chown -R "${_UID}:${_UID}" /home/${_USER} \
            && _MKCERT_CA_OU=${CA_NAME} mkcert -install \
            && _MKCERT_CERT_OU=${CERT_NAME} mkcert localhost "${CERT_NAME}" 127.0.0.1'

(
    DST_DIR="${CURRENT_DIR}/mkcert/certs"

    mkdir -p "${DST_DIR}"

    cp "${CURRENT_DIR}/mkcert/rootcerts/rootCA.pem" "${DST_DIR}/readonly-root.crt"

    chmod 600 "${CURRENT_DIR}/mkcert/rootcerts/rootCA-key.pem"
    cp "${CURRENT_DIR}/mkcert/rootcerts/rootCA-key.pem" "${DST_DIR}/readonly-root.key"
    # chmod 400 "${CURRENT_DIR}/mkcert/rootcerts/rootCA-key.pem" "${DST_DIR}/readonly-root.key"

    SRC_CRT="${CURRENT_DIR}/mkcert/usercerts/localhost+2.pem"
    SRC_KEY="${CURRENT_DIR}/mkcert/usercerts/localhost+2-key.pem"

    cp "${SRC_CRT}" "${DST_DIR}/ldap.crt" \
        && cp "${SRC_CRT}" "${DST_DIR}/ldapadmin.crt" \
        && cp "${SRC_CRT}" "${DST_DIR}/keycloak.crt" \
        && cp "${SRC_CRT}" "${DST_DIR}/readonly.crt"

    cp "${SRC_KEY}" "${DST_DIR}/ldap.key" \
        && cp "${SRC_KEY}" "${DST_DIR}/ldapadmin.key" \
        && cp "${SRC_KEY}" "${DST_DIR}/keycloak.key" \
        && cp "${SRC_KEY}" "${DST_DIR}/readonly.key"
)

exit 0

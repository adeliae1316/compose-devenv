# Use self signed certs

- prepare

    ```bash
    wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz \
    && sudo rm -rf /usr/local/go \
    && sudo tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz \
    && rm go1.18.3.linux-amd64.tar.gz \
    && echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.bashrc \
    && source $HOME/.bashrc

    git clone https://github.com/adeliae1316/mkcert.git && cd mkcert
    sudo apt install libnss3-tools
    go build -ldflags "-X main.Version=$(git describe --tags)"
    sudo cp mkcert /usr/local/bin
    ```

- create a new local CA and duplicate for service 

    ```bash
    _MKCERT_CA_OU='Workspace self-signed CA' mkcert -install
    mkdir -p certs && cd certs && cp $(mkcert -CAROOT)/rootCA.pem .
    ```

- create a new certs and duplicate for each service 

    ```bash
    mkdir -p certs && cd certs
    _MKCERT_CERT_OU='192.168.77.48 (vm)' mkcert localhost 192.168.77.48 127.0.0.1
    cp localhost+2.pem ldap.crt && cp localhost+2.pem ldapadmin.crt && cp localhost+2.pem keycloak.crt
    cp localhost+2-key.pem ldap.key && cp localhost+2-key.pem ldapadmin.key && cp localhost+2-key.pem keycloak.key
    ```

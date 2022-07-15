FROM golang:bullseye
LABEL maintainer adeliae1316 <knsak.ug487@gmail.com>

# install dependencies
RUN apt-get update \
    && apt-get install -y \
    git \
    gosu \
    sudo \
    libnss3-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# install mkcert
RUN git clone https://github.com/adeliae1316/mkcert.git \
    && cd mkcert \
    && go build -ldflags "-X main.Version=$(git describe --tags)" \
    && mv mkcert /usr/local/bin \
    && cd .. \
    && rm -r mkcert

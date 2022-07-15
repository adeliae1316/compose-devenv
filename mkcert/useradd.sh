#!/usr/bin/env bash

# need to pass following variables: _UID as user id, _USER as username.

apt update \
    && apt install -y sudo gosu \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

groupadd --gid ${_UID} ${_USER} \
    && useradd --uid ${_UID} --gid ${_UID} --create-home ${_USER} &> /dev/null \
    && echo "${_USER}:${_USER}" | chpasswd \
    && echo "${_USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${_USER} \
    && chmod 0440 /etc/sudoers.d/${_USER}

export HOME=/home/${_USER}
exec /usr/sbin/gosu ${_USER} "$@"

exit 0

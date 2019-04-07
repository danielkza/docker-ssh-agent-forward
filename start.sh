#!/usr/bin/env bash

set -eo pipefail

ssh_image=cobli/docker-ssh-agent-forward
container_name=cobli_docker-ssh-agent-forward
volume_name=ssh-agent
tmp_dir=/tmp/docker-ssh-auth-forward
ssh_pid_file="${tmp_dir}/ssh.pid"

mkdir -p "$tmp_dir"
chmod 0700 "$tmp_dir"

container_id=$(docker ps -aqf "name=${container_name}" || :)
if [ -z "$container_id" ]; then
    docker build -t "$ssh_image" .
    container_id=$(docker run \
        -d --rm \
        --name="${container_name}" \
        --volume "${volume_name}:/ssh-agent" \
        --publish=22 \
        "$ssh_image")
fi

ssh_priv_key="${tmp_dir}/id_rsa"
if [ ! -f "${ssh_priv_key}" ]; then
    ssh-keygen -N '' -t rsa -b 3072 -f "${ssh_priv_key}"
fi

docker exec -i "$container_id" sh -s <<EOF
pub_key='$(cat "${ssh_priv_key}.pub")'
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if ! grep -qF "\$pub_key" /root/.ssh/authorized_keys; then
    echo "\$pub_key" >> /root/.ssh/authorized_keys
fi
chmod 600 /root/.ssh/authorized_keys
EOF

if ! pgrep -F "$ssh_pid_file" >/dev/null 2>&1; then
    ssh_addr=$(docker port "$container_id" 22/tcp)
    ssh_port="${ssh_addr##*:}"

    ssh -f -i "$ssh_priv_key" -A  -p "$ssh_port" \
        -o BatchMode=no -o NoHostAuthenticationForLocalhost=yes \
        "root@127.0.0.1" \
        'socat UNIX-CONNECT:$SSH_AUTH_SOCK UNIX-LISTEN:/ssh-agent/sock,fork,unlink-leary,perm-early=0666'
    pgrep --exact --parent 1 --newest ssh > "$ssh_pid_file"
fi

FROM sickp/alpine-sshd:7.5-r2

RUN apk add --no-cache socat

VOLUME ["/ssh-agent"]

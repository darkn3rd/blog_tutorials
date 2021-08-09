FROM alpine:3.14

# install utilities
RUN apk add --update --no-cache openssh \
 curl \
 tcptraceroute \
 bash \
 vim

RUN mkdir ~/.ssh && chmod 700 ~/.ssh

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"

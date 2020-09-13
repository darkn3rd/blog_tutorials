FROM ubuntu:focal
RUN apt-get -qq update && \
    apt-get install -y curl python3-pip && \
    rm -rf /var/lib/apt/lists/*
# Install MinIO Client
RUN curl --silent -O https://dl.min.io/client/mc/release/linux-amd64/mc && \
    chmod +x mc && mv mc /usr/local/bin
# Install s3cmd
RUN pip3 install s3cmd
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

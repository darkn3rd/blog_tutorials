FROM python:3.9.6-buster

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# application package manifest
COPY requirements.txt /usr/src/app/
RUN pip install -r requirements.txt

# application source code
COPY . /usr/src/app

# install packages: jq
RUN apt-get update && apt-get install -y --no-install-recommends jq vim \
	&& rm -rf /var/lib/apt/lists/*

# grpcurl
ADD https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto api.proto
ADD https://github.com/fullstorydev/grpcurl/releases/download/v1.8.1/grpcurl_1.8.1_linux_x86_64.tar.gz /usr/src/app
RUN tar -xzf grpcurl_1.8.1_linux_x86_64.tar.gz \
  && rm grpcurl_1.8.1_linux_x86_64.tar.gz \
  && mv grpcurl /usr/local/bin

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"

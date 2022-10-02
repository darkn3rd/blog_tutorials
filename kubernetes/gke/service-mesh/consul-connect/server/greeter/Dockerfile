FROM python:3.9.6-buster
RUN mkdir -p /usr/src/app/data
WORKDIR /usr/src/app

# application package manifest
COPY requirements.txt /usr/src/app/
RUN pip install -r requirements.txt
# application source code
COPY . /usr/src/app

# grpcurl
ADD https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto api.proto
ADD https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_x86_64.tar.gz /tmp
RUN tar -xzf /tmp/grpcurl_1.8.7_linux_x86_64.tar.gz -C /tmp \
  && rm /tmp/grpcurl_1.8.7_linux_x86_64.tar.gz \
  && mv /tmp/grpcurl /usr/local/bin

CMD python greeter_server.py

.PHONY: test build push clean

build:
	@docker build -t ${AZ_ACR_LOGIN_SERVER}/pydgraph-client:latest .

push:
	@docker push ${AZ_ACR_LOGIN_SERVER}/pydgraph-client:latest

test: build
	docker run --detach --name pydgraph_client ${AZ_ACR_LOGIN_SERVER}/pydgraph-client:latest

clean:
	docker stop pydgraph_client && docker rm pydgraph_client

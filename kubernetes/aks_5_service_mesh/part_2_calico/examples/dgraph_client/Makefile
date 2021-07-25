.PHONY: test build push clean

build:
	@docker build -t darknerd/pydgraph-client:latest .

push:
	@docker push darknerd/pydgraph-client:latest

test: build
	docker run --detach --name pydgraph_client darknerd/pydgraph-client:latest

clean:
	docker stop pydgraph_client && docker rm pydgraph_client

.PHONY: test build push clean

build:
	@docker build -t gcr.io/$GCR_PROJECT_ID/pydgraph-client:latest .

push:
	@docker push gcr.io/$GCR_PROJECT_ID//pydgraph-client:latest

test: build
	@docker run --detach --name pydgraph_client gcr.io/$GCR_PROJECT_ID/pydgraph-client:latest

clean:
	@docker stop pydgraph_client && docker rm pydgraph_client

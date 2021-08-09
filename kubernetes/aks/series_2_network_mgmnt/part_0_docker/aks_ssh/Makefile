.PHONY: build push 

build:
	@docker build -t ${AZ_ACR_LOGIN_SERVER}/aks-ssh:latest .

push:
	@docker push ${AZ_ACR_LOGIN_SERVER}/aks-ssh:latest

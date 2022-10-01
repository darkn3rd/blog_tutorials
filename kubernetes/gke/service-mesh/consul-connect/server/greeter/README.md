# Greeter (Python)


The `greeter_service.py` was from the gist below.  The author has some really intriguing blogs, please check him out.

* https://gist.github.com/viglesiasce
* http://testingclouds.wordpress.com/


# Setup Locally

```bash
pyenv virtualenv $PYTHON_VERSION greeter-$PYTHON_VERSION
pyenv shell greeter-$PYTHON_VERSION
```

# Running the Server

```bash
python greeter_server.py
```


# Running the Client

```bash
grpcurl -plaintext localhost:9080 helloworld.Greeter/SayHello
curl localhost:8080/health
```

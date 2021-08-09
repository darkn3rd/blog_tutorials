# Dgraph example schema and data

## Pyenv

I highly recommend using [pyenv](https://github.com/pyenv/pyenv) with [pyenv-virtualenv](https://github.com/pyenv/pyenv-virtualenv)to manage python versions and virtualenv environments.

Using these tools, you can install Python3 and create a virtual env for pydgraph.

### Install Latest Python3 with Pyenv

```bash
# this command requires GNU grep (not BSD grep)
LATEST_PYTHON3=$(
 pyenv install --list | tr -d ' ' | grep -oP '^3\.*\d+\.\d+' | sort -V | tail -1
)

pyenv install $LATEST_PYTHON3
pyenv global $LATEST_PYTHON3
pip install --upgrade pip
```

### Use Virtualenv for pydgraph

```bash
pyenv virtualenv $LATEST_PYTHON3 pydgraph
pyenv shell pydgraph
pip install --upgrade pip
```

## Pydgraph requirements

```bash
pip install -r requirements.txt
```

## Upload Schema and Data

```bash
export AZ_DNS_DOMAIN="<your-domain-goes-here>"
export DGRAPH_ALPHA_SERVER="dgraph.$AZ_DNS_DOMAIN:443"
python3 getting_started_data.py
```

#!/usr/bin/env bash

PREFIX="gist.githubusercontent.com/darkn3rd"
FILES=(
  "4c100d72e437ac8996a616acc232c797/raw/5e225703a7fc7df76c080c2171eb0e2b6d64daec/Dockerfile"
  "53d9b7bc4d93c60d95635cd5c83dba27/raw/934eb4127f268e734ccbbd2a3710dd4cf5409c79/Makefile"
  "6a2b6e275c1975a06f600fbce445387c/raw/15bfbd2bc344802ad2291f1b414dd0856a82f3d9/load_data.py"
  "6a2766c0a83a2801e5cae2637e3a6359/raw/189b6f65a47b76494fe65e6a76a92c8cc9359f18/requirements.txt"
  "b712bbc52f65c68a5303c74fd08a3214/raw/b4933d2b286aed6e9c32decae36f31c9205c45ba/sw.schema"
  "94512033203c22b9be434b1e374b1c32/raw/1688b28e98634051b7e775a41649bcedb4186cbd/sw.nquads.rdf"
  "d209820d7cf61b5bbb9cec3bae724330/raw/c2bd8e7bbb1d4a808c64587fe7b6c0aa204a07f1/helmfile.yaml"
)

cd ./examples/pydgraph
for FILE in ${FILES[*]}; do curl --silent --remote-name --location https://$PREFIX/$FILE; done

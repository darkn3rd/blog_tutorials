#!/usr/bin/env bash

WORKAREA=${HOME}/vbox_tutorial
mkdir -p ${WORKAREA}/cookbooks && cd ${WORKAREA}/cookbooks

# Generate example
chef generate cookbook helloworld && cd helloworld
# Create Ubuntu and CentOS systems
kitchen create

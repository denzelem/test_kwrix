FROM ubuntu:20.04

# Set the working directory in the container
WORKDIR /usr/src/app

ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NOWARNINGS="yes"
ARG CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    bash \
    ruby \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

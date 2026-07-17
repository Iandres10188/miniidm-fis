FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       krb5-user \
       ldap-utils \
       openssl \
       curl \
       dnsutils \
       iputils-ping \
       netcat-openbsd \
       ca-certificates \
       time \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]

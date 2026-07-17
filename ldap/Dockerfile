FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN echo "slapd slapd/no_configuration boolean true" \
       | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       slapd \
       ldap-utils \
       sasl2-bin \
       libsasl2-modules \
       libsasl2-modules-gssapi-mit \
       krb5-user \
       openssl \
       ca-certificates \
       netcat-openbsd \
       procps \
    && usermod -aG sasl openldap \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/ldap-entrypoint.sh /usr/local/sbin/ldap-entrypoint.sh

RUN chmod 755 /usr/local/sbin/ldap-entrypoint.sh

EXPOSE 389/tcp
EXPOSE 636/tcp

ENTRYPOINT ["/usr/local/sbin/ldap-entrypoint.sh"]

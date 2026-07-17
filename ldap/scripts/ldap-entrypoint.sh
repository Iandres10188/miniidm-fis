#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="/etc/ldap/slapd.d"
DATABASE_DIR="/var/lib/ldap"
TLS_DIR="/etc/ldap/tls"
SASL_RUN_DIR="/var/run/saslauthd"
LDAP_ROLE="${LDAP_ROLE:-provider}"

required_variables=(
    LDAP_DOMAIN
    LDAP_BASE_DN
    LDAP_ADMIN_PASSWORD
    KRB_REALM
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        echo "ERROR: La variable ${variable} no está definida."
        exit 1
    fi
done

echo "=========================================="
echo "Preparando certificados TLS"
echo "=========================================="

mkdir -p "${TLS_DIR}"

install \
    -o openldap \
    -g openldap \
    -m 0644 \
    /certificates/server.cert.pem \
    "${TLS_DIR}/server.cert.pem"

install \
    -o openldap \
    -g openldap \
    -m 0640 \
    /certificates/server.key.pem \
    "${TLS_DIR}/server.key.pem"

install \
    -o openldap \
    -g openldap \
    -m 0644 \
    /certificates/ca.cert.pem \
    "${TLS_DIR}/ca.cert.pem"

echo "=========================================="
echo "Preparando keytab de saslauthd"
echo "=========================================="

install \
    -o root \
    -g root \
    -m 0600 \
    /keytabs/ldap1.keytab \
    /etc/saslauthd.keytab

cat > /etc/saslauthd.conf <<EOF_SASL
krb5_keytab: /etc/saslauthd.keytab
krb5_verify_principal: saslauthd
EOF_SASL

mkdir -p /etc/ldap/sasl2

cat > /etc/ldap/sasl2/slapd.conf <<'EOF_SLAPD_SASL'
pwcheck_method: saslauthd
EOF_SLAPD_SASL

mkdir -p "${SASL_RUN_DIR}"
chown root:sasl "${SASL_RUN_DIR}"
chmod 750 "${SASL_RUN_DIR}"

# Directorio donde slapd guarda PID y argumentos.
mkdir -p /var/run/slapd
chown openldap:openldap /var/run/slapd
chmod 755 /var/run/slapd

if [[ ! -f "${CONFIG_DIR}/cn=config.ldif" ]]; then
    echo "=========================================="
    echo "Inicializando configuración OpenLDAP"
    echo "=========================================="

    rm -rf "${CONFIG_DIR:?}"/*
    rm -rf "${DATABASE_DIR:?}"/*

    mkdir -p "${CONFIG_DIR}" "${DATABASE_DIR}"

    ADMIN_PASSWORD_HASH="$(
        slappasswd -s "${LDAP_ADMIN_PASSWORD}"
    )"

    cat > /tmp/slapd.conf <<EOF_SLAPD
include         /etc/ldap/schema/core.schema
include         /etc/ldap/schema/cosine.schema
include         /etc/ldap/schema/nis.schema
include         /etc/ldap/schema/inetorgperson.schema

pidfile         /var/run/slapd/slapd.pid
argsfile        /var/run/slapd/slapd.args

modulepath      /usr/lib/ldap
moduleload      back_mdb

TLSCACertificateFile      ${TLS_DIR}/ca.cert.pem
TLSCertificateFile        ${TLS_DIR}/server.cert.pem
TLSCertificateKeyFile     ${TLS_DIR}/server.key.pem
TLSVerifyClient           never

database        mdb
maxsize         1073741824
suffix          "${LDAP_BASE_DN}"
rootdn          "cn=admin,${LDAP_BASE_DN}"
rootpw          ${ADMIN_PASSWORD_HASH}
directory       ${DATABASE_DIR}

index objectClass eq
index uid,cn,mail eq,pres,sub
index uidNumber,gidNumber eq

access to attrs=userPassword
    by dn.exact="cn=admin,${LDAP_BASE_DN}" write
    by self write
    by anonymous auth
    by * none

access to *
    by dn.exact="cn=admin,${LDAP_BASE_DN}" write
    by * read
EOF_SLAPD

    echo "=========================================="
    echo "Creando árbol LDAP y usuarios"
    echo "=========================================="

    cat > /tmp/base.ldif <<EOF_BASE
dn: ${LDAP_BASE_DN}
objectClass: top
objectClass: dcObject
objectClass: organization
o: FIS
dc: fis

dn: ou=people,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: people

dn: ou=groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: groups

dn: cn=students,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: students
gidNumber: 10000

dn: cn=teachers,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: teachers
gidNumber: 10001

dn: cn=employees,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: employees
gidNumber: 10002

dn: uid=ionate,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: ionate
sn: Onate
givenName: Ian
cn: Ian Onate
displayName: Ian Onate
mail: ionate@fis.epn.edu.ec
uidNumber: 20001
gidNumber: 10000
homeDirectory: /home/ionate
loginShell: /bin/bash
userPassword: {SASL}ionate@${KRB_REALM}

dn: uid=jperez,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: jperez
sn: Perez
givenName: Juan
cn: Juan Perez
displayName: Juan Perez
mail: jperez@fis.epn.edu.ec
uidNumber: 20002
gidNumber: 10000
homeDirectory: /home/jperez
loginShell: /bin/bash
userPassword: {SASL}jperez@${KRB_REALM}

dn: uid=malvan,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: malvan
sn: Alvan
givenName: Maria
cn: Maria Alvan
displayName: Maria Alvan
mail: malvan@fis.epn.edu.ec
uidNumber: 20003
gidNumber: 10001
homeDirectory: /home/malvan
loginShell: /bin/bash
userPassword: {SASL}malvan@${KRB_REALM}

dn: uid=dnoboa,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: dnoboa
sn: Noboa
givenName: Diego
cn: Diego Noboa
displayName: Diego Noboa
mail: dnoboa@fis.epn.edu.ec
uidNumber: 20004
gidNumber: 10002
homeDirectory: /home/dnoboa
loginShell: /bin/bash
userPassword: {SASL}dnoboa@${KRB_REALM}
EOF_BASE

    echo "=========================================="
    echo "Creando inicialmente la base MDB"
    echo "=========================================="

    slapadd \
        -f /tmp/slapd.conf \
        -b "${LDAP_BASE_DN}" \
        -l /tmp/base.ldif

    echo "=========================================="
    echo "Convirtiendo slapd.conf a slapd.d"
    echo "=========================================="

    slaptest \
        -f /tmp/slapd.conf \
        -F "${CONFIG_DIR}"

    if [[ "${LDAP_ROLE}" == "consumer" ]]; then
        echo "=========================================="
        echo "Preparando base vacía para replicación"
        echo "=========================================="

        rm -rf "${DATABASE_DIR:?}"/*
    fi

    echo "OpenLDAP inicializado correctamente."
else
    echo "La configuración OpenLDAP ya existe."
    echo "Se conservarán los datos almacenados."
fi

chown -R openldap:openldap "${CONFIG_DIR}"
chown -R openldap:openldap "${DATABASE_DIR}"
chown -R openldap:openldap "${TLS_DIR}"

chmod 750 "${CONFIG_DIR}"
chmod 750 "${DATABASE_DIR}"

echo "=========================================="
echo "Iniciando saslauthd con Kerberos"
echo "=========================================="

/usr/sbin/saslauthd \
    -a kerberos5 \
    -d \
    -m "${SASL_RUN_DIR}" \
    -n 1 &

sleep 2

if [[ ! -S "${SASL_RUN_DIR}/mux" ]]; then
    echo "ERROR: No se creó el socket de saslauthd."
    exit 1
fi

echo "=========================================="
echo "Iniciando OpenLDAP"
echo "=========================================="

exec slapd \
    -h "ldap:/// ldapi:/// ldaps:///" \
    -u openldap \
    -g openldap \
    -d 0

#!/usr/bin/env bash
set -euo pipefail

OUT="/work/out"
PRIVATE_DIR="${OUT}/private"
CERTS_DIR="${OUT}/certs"
CSR_DIR="${OUT}/csr"
EXT_DIR="${OUT}/ext"

mkdir -p \
    "${PRIVATE_DIR}" \
    "${CERTS_DIR}" \
    "${CSR_DIR}" \
    "${EXT_DIR}"

chmod 700 "${PRIVATE_DIR}"

if [[ -z "${CA_KEY_PASSWORD:-}" ]]; then
    echo "ERROR: La variable CA_KEY_PASSWORD no está definida."
    exit 1
fi

CA_KEY="${PRIVATE_DIR}/fis-root-ca.key.pem"
CA_CERT="${CERTS_DIR}/fis-root-ca.cert.pem"

create_ca() {
    if [[ -f "${CA_KEY}" && -f "${CA_CERT}" ]]; then
        echo "La CA raíz ya existe. No se generará nuevamente."
        return
    fi

    echo "=========================================="
    echo "Generando llave privada ECDSA de la CA"
    echo "=========================================="

    openssl genpkey \
        -algorithm EC \
        -aes-256-cbc \
        -pass env:CA_KEY_PASSWORD \
        -pkeyopt ec_paramgen_curve:prime256v1 \
        -out "${CA_KEY}"

    chmod 600 "${CA_KEY}"

    echo "=========================================="
    echo "Generando certificado raíz autofirmado"
    echo "=========================================="

    openssl req \
        -x509 \
        -new \
        -sha256 \
        -key "${CA_KEY}" \
        -passin env:CA_KEY_PASSWORD \
        -days 3650 \
        -out "${CA_CERT}" \
        -subj "/C=EC/ST=Pichincha/L=Quito/O=EPN/OU=FIS/CN=FIS Root CA" \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" \
        -addext "subjectKeyIdentifier=hash"

    chmod 644 "${CA_CERT}"
}

issue_server_certificate() {
    local name="$1"
    local common_name="$2"
    local sans="$3"

    local key="${PRIVATE_DIR}/${name}.key.pem"
    local csr="${CSR_DIR}/${name}.csr.pem"
    local cert="${CERTS_DIR}/${name}.cert.pem"
    local ext="${EXT_DIR}/${name}.ext"

    if [[ -f "${cert}" ]]; then
        echo "El certificado ${name} ya existe. Se conservará."
        return
    fi

    echo
    echo "=========================================="
    echo "Generando certificado para ${name}"
    echo "=========================================="

    openssl genpkey \
        -algorithm EC \
        -pkeyopt ec_paramgen_curve:prime256v1 \
        -out "${key}"

    chmod 600 "${key}"

    openssl req \
        -new \
        -sha256 \
        -key "${key}" \
        -out "${csr}" \
        -subj "/C=EC/ST=Pichincha/L=Quito/O=EPN/OU=FIS/CN=${common_name}" \
        -addext "subjectAltName=${sans}"

    cat > "${ext}" <<EXTENSION
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyAgreement
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
subjectAltName=${sans}
EXTENSION

    openssl x509 \
        -req \
        -sha256 \
        -in "${csr}" \
        -CA "${CA_CERT}" \
        -CAkey "${CA_KEY}" \
        -passin env:CA_KEY_PASSWORD \
        -set_serial "0x$(openssl rand -hex 16)" \
        -days 825 \
        -extfile "${ext}" \
        -out "${cert}"

    chmod 644 "${cert}"
}

create_ca

issue_server_certificate \
    "ldap1" \
    "ldap1.fis.epn.edu.ec" \
    "DNS:ldap1.fis.epn.edu.ec,DNS:ldap1,DNS:ldap.fis.epn.edu.ec"

issue_server_certificate \
    "ldap2" \
    "ldap2.fis.epn.edu.ec" \
    "DNS:ldap2.fis.epn.edu.ec,DNS:ldap2,DNS:ldap.fis.epn.edu.ec"

issue_server_certificate \
    "kdc1" \
    "kdc1.fis.epn.edu.ec" \
    "DNS:kdc1.fis.epn.edu.ec,DNS:kdc1"

issue_server_certificate \
    "kdc2" \
    "kdc2.fis.epn.edu.ec" \
    "DNS:kdc2.fis.epn.edu.ec,DNS:kdc2"

issue_server_certificate \
    "web" \
    "web.fis.epn.edu.ec" \
    "DNS:web.fis.epn.edu.ec,DNS:web"

echo
echo "=========================================="
echo "Verificando certificados emitidos"
echo "=========================================="

for cert in \
    "${CERTS_DIR}/ldap1.cert.pem" \
    "${CERTS_DIR}/ldap2.cert.pem" \
    "${CERTS_DIR}/kdc1.cert.pem" \
    "${CERTS_DIR}/kdc2.cert.pem" \
    "${CERTS_DIR}/web.cert.pem"
do
    openssl verify \
        -CAfile "${CA_CERT}" \
        "${cert}"
done

echo
echo "=========================================="
echo "PKI creada correctamente"
echo "=========================================="

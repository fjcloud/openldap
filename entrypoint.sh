#!/bin/bash
set -e

# Generate password hashes
LDAP_ADMIN_PASSWORD_HASH=$(slappasswd -s "${LDAP_ADMIN_PASSWORD}")
LDAP_CONFIG_PASSWORD_HASH=$(slappasswd -s "${LDAP_CONFIG_PASSWORD}")

# Initialize new LDAP database if it doesn't exist
if [ ! -f "${LDAP_DATA_DIR}/DB_CONFIG" ]; then
    echo "Initializing new LDAP database..."
    
    # Copy default DB_CONFIG
    cp /usr/share/openldap-servers/DB_CONFIG.example "${LDAP_DATA_DIR}/DB_CONFIG"
    
    # Initialize LDAP database
    slapadd -F "${LDAP_CONFIG_DIR}" -n 0 << EOF
dn: cn=config
objectClass: olcGlobal
cn: config
olcArgsFile: /var/run/openldap/slapd.args
olcPidFile: /var/run/openldap/slapd.pid

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

dn: olcDatabase={0}config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: {0}config
olcRootDN: cn=config
olcRootPW: ${LDAP_CONFIG_PASSWORD_HASH}

dn: olcDatabase={1}mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: {1}mdb
olcDbDirectory: ${LDAP_DATA_DIR}
olcSuffix: ${LDAP_BASE_DN}
olcRootDN: cn=admin,${LDAP_BASE_DN}
olcRootPW: ${LDAP_ADMIN_PASSWORD_HASH}
olcDbIndex: objectClass eq
olcDbIndex: cn,uid eq
olcDbIndex: uidNumber,gidNumber eq
olcDbIndex: member,memberUid eq
olcAccess: to attrs=userPassword,shadowLastChange
  by self write
  by anonymous auth
  by * none
olcAccess: to *
  by self write
  by users read
  by * none
EOF

    # Set correct permissions
    chown -R ${LDAP_USER}:${LDAP_GROUP} "${LDAP_DATA_DIR}" "${LDAP_CONFIG_DIR}"
fi

# Start slapd in the foreground
exec slapd -h "ldap:/// ldapi:///" -u ${LDAP_USER} -g ${LDAP_GROUP} -F "${LDAP_CONFIG_DIR}" -d ${LDAP_LOG_LEVEL:-256}
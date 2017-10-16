#!/bin/bash

[[ "TRACE" ]] && set -x

: ${REALM:=CLOUD.COM}
: ${DOMAIN_REALM:=cloud.com}
: ${KERB_MASTER_KEY:=masterkey}
: ${KERB_ADMIN_USER:=root}
: ${KERB_ADMIN_PASS:=admin}
: ${LDAP_HOST:=ldap://ldap.cloud.com}

fix_nameserver() {
  cat>/etc/resolv.conf<<EOF
nameserver $NAMESERVER_IP
search $SEARCH_DOMAINS
EOF
}

fix_hostname() {
  sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
}

create_config() {
  : ${KDC_ADDRESS:=$(hostname -f)}

  cat>/etc/krb5.conf<<EOF
[logging]
 default = FILE:/var/log/kerberos/krb5libs.log
 kdc = FILE:/var/log/kerberos/krb5kdc.log
 admin_server = FILE:/var/log/kerberos/kadmind.log

[libdefaults]
 default_realm = $REALM
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 proxiable = true

[realms]
 $REALM = {
  kdc = $KDC_ADDRESS
  admin_server = $KDC_ADDRESS
  database_module = openldap_ldapconf
 }

[domain_realm]
 .$DOMAIN_REALM = $REALM
 $DOMAIN_REALM = $REALM

[dbdefaults]
        ldap_kerberos_container_dn = cn=krbContainer,dc=cloud,dc=com

[dbmodules]
        openldap_ldapconf = {
                db_library = kldap
                ldap_kdc_dn = cn=kdc-srv,ou=krb5,dc=cloud,dc=com
                ldap_kadmind_dn = cn=adm-srv,ou=krb5,dc=cloud,dc=com
                ldap_service_password_file = /etc/krb5kdc/service.keyfile
                ldap_conns_per_server = 5
                ldap_servers = $LDAP_HOST 
        }
EOF
cat>/etc/krb5kdc/kdc.conf<<EOF
[kdcdefaults]
    kdc_ports = 750,88

[realms]
    CLOUD.COM = {
        database_name = /var/lib/krb5kdc/principal
        admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
        acl_file = /etc/krb5kdc/kadm5.acl
        key_stash_file = /etc/krb5kdc/stash
        kdc_ports = 750,88
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = des3-hmac-sha1
        supported_enctypes = aes256-cts:normal arcfour-hmac:normal des3-hmac-sha1:normal des-cbc-crc:normal des:normal des:v4 des:norealm des:onlyrealm des:afs3
        default_principal_flags = +preauth
    }
EOF
cat>/etc/krb5kdc/kadm5.acl<<EOF
*/admin *
EOF

}

create_containers() {
  kdb5_ldap_util -D cn=admin,dc=cloud,dc=com -w sumit \
-H $LDAP_HOST create -subtrees cn=krbContainer,dc=cloud,dc=com -r $REALM -s -P $KERB_ADMIN_PASS
  kdb5_ldap_util -D cn=admin,dc=cloud,dc=com -w sumit stashsrvpw \
-f /etc/krb5kdc/service.keyfile cn=kdc-srv,ou=krb5,dc=cloud,dc=com
  kdb5_ldap_util -D cn=admin,dc=cloud,dc=com -w sumit stashsrvpw \
-f /etc/krb5kdc/service.keyfile cn=adm-srv,ou=krb5,dc=cloud,dc=com
}

create_db() {
  mkdir -p /var/log/kerberos
  touch /var/log/kerberos/{krb5kdc,kadmin,krb5lib}.log
  chmod -R 750  /var/log/kerberos

  #database will be created in ldap
  #/usr/sbin/kdb5_util -P $KERB_MASTER_KEY -r $REALM create -s
}

start_kdc() {
  invoke-rc.d krb5-admin-server start  
  invoke-rc.d krb5-kdc start
}

restart_kdc() {
  invoke-rc.d krb5-admin-server start
  invoke-rc.d krb5-kdc start

}

create_admin_user() {
  kadmin.local -q "addprinc -pw $KERB_ADMIN_PASS $KERB_ADMIN_USER/admin"
  echo "*/admin@$REALM *" > /etc/krb5kdc/kadm5.acl
}

main() {
#  fix_nameserver
  fix_hostname

  if [ ! -f /kerberos_initialized ]; then
    create_config
    create_db
    create_containers
    create_admin_user
    start_kdc

    touch /kerberos_initialized
  fi

  if [ ! -f /var/kerberos/krb5kdc/principal ]; then
    while true; do sleep 1000; done
  else
    start_kdc
    tail -F /var/log/kerberos/krb5kdc.log
  fi
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"

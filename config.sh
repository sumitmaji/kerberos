#!/bin/bash

[[ "TRACE" ]] && set -x

: ${REALM:=CLOUD.COM}
: ${DOMAIN_REALM:=cloud.com}
: ${KERB_MASTER_KEY:=masterkey}
: ${KERB_ADMIN_USER:=root}
: ${KERB_ADMIN_PASS:=admin}
: ${SEARCH_DOMAINS:=search.consul node.dc1.consul}

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

[realms]
 $REALM = {
  kdc = $KDC_ADDRESS
  admin_server = $KDC_ADDRESS
 }

[domain_realm]
 .$DOMAIN_REALM = $REALM
 $DOMAIN_REALM = $REALM
EOF
}

create_db() {
  mkdir -p /var/log/kerberos
  touch /var/log/kerberos/{krb5kdc,kadmin,krb5lib}.log
  chmod -R 750  /var/log/kerberos

  /usr/sbin/kdb5_util -P $KERB_MASTER_KEY -r $REALM create -s
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

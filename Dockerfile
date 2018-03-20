FROM sumit/base:latest 
MAINTAINER Sumit Kumar Maji

# kerberos
RUN apt-get update 
RUN apt-get install -yq krb5-kdc krb5-admin-server krb5-kdc-ldap ntp ntpdate nmap 
RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d
EXPOSE 88 749

ADD ./config.sh /config.sh
ADD ./config /config

ENTRYPOINT ["/config.sh"]

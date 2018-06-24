FROM master.cloud.com:5000/base-trusty
MAINTAINER Sumit Kumar Maji

ARG DEBIAN_FRONTEND=noninteractive

# kerberos
# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl \
&& ln -sf /bin/true /sbin/initctl
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
&& apt-get install -yq apt debconf \
&& apt-get upgrade -yq \
&& apt-get -y -o Dpkg::Options::="--force-confdef" upgrade \
&& apt-get -y dist-upgrade

RUN echo "kerberos krb5-config/default_realm string default.svc.cloud.uat" | debconf-set-selections

RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -yq krb5-kdc krb5-admin-server krb5-kdc-ldap ntp ntpdate nmap

RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d

EXPOSE 88 749

ADD ./config.sh /config.sh
ADD ./config /config

ENTRYPOINT ["/config.sh"]

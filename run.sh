#!/bin/bash
docker run -it -v /dev/urandom:/dev/random --name kerberos -h kerberos.cloud.com --net cloud.com sumit/kerberos /bin/bash

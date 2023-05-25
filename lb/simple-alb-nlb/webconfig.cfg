#cloud-config

# Xenial Ubuntu 

output:
    init:
        output: "> /var/log/cloud-init.out"
        error: "> /var/log/cloud-init.err"
    config: "tee -a /var/log/cloud-config.log"
    final:
        - ">> /var/log/cloud-final.out"
        - "/var/log/cloud-final.err"


package_update: true

package_upgrade: true

packages:
- docker.io

runcmd:
  - docker pull httpd
  - WEBSRV=$(curl http://169.254.169.254/latest/meta-data/instance-id)
  - echo Welcome to $WEBSRV > index.html
  - docker run -dit --name my-apache-app -p 8080:80 -v "$PWD":/usr/local/apache2/htdocs/ httpd:2.4

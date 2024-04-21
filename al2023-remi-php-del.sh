#!/bin/bash

# Dump function
dump_info() {
  echo "[dnf history]"
  dnf history

  echo "[rpm packages]"
  rpm -qa | sort

  echo "[file context]"
  semanage fcontext -lC
}

cd $(dirname $(readlink -f "${BASH_SOURCE:-$0}"))
set -eux

# Current install
which php-config

readonly remidir=$(readlink -f "$(php-config --prefix)/../..")
readonly phpv=${remidir: -2}
readonly tempfpfx="$(basename $0 .sh)-$(date +'%Y%m%d')"

test ${remidir:0:10} = '/opt/remi/'
test -d ${remidir}

# Dump before
tempf=$(mktemp -t ${tempfpfx}-before-XXXXX.tmp)
dump_info > ${tempf}
echo "### before --> ${tempf}"

# Disable php-fpm, alternatives
alternatives --remove-all php || true
systemctl revert php${phpv}-php-fpm.service
systemctl disable --now php${phpv}-php-fpm.service
systemctl daemon-reload

# Deletion
dnf -q -y remove 'php*'
rm -rf /opt/remi/php${phpv}* /etc/opt/remi/php${phpv}* /var/opt/remi/php${phpv}*
rm -f /var/log/php-fpm /etc/php.ini

# Remove file-context
semanage fcontext -lC | grep -F '/opt/remi/php' | grep -E '^/.*\s+=\s+/.*' \
 | sed -E 's/^(.+)\s+=\s+(.+)$/semanage fcontext -d -e \2 \1/' | bash
semanage fcontext -d -t httpd_log_t /var/log/php-fpm || true
restorecon -Rv /opt/remi/ /var/log/ || true

# Dump after
tempf=$(mktemp -t ${tempfpfx}-after-XXXXX.tmp)
dump_info > ${tempf}
echo "### after --> ${tempf}"

# Show information
ls -l /opt/remi/ /etc/opt/remi/ /var/opt/remi/

exit 0

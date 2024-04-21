#!/bin/bash

cd $(dirname $(readlink -f "${BASH_SOURCE:-$0}"))
set -ex

# Install function
install_php() {
  local remiv=$1
  local phpv=$2
  shift 2

  set +x
  declare -a mods=()

  for mod
  do
    mods+=( php${phpv}-php-${mod} )
  done
  set -x

  dnf -q -y \
   --excludepkgs='php php-* php8.*' \
   --enablerepo="al2023-f34*,al2023-remi${remiv}*" \
   --exclude='php-*' install "${mods[@]}"
}

# Dump function
dump_info() {
  echo "[dnf history]"
  dnf history

  echo "[rpm packages]"
  rpm -qa | sort

  echo "[file context]"
  semanage fcontext -lC
}

if php -v
then
  echo already installed
  exit 1
fi

case "$1" in
  56|7[01234]|8[01])
    remiv=34
    ;;
  82)
    remiv=35
    ;;
  *)
    phpv=${1:?"Usage: $0 [56|70-74|80-82]"}
    exit 1
    ;;
esac

phpv="$1"

readonly remidir="/opt/remi/php${phpv}"
readonly tempfpfx="$(basename $0 .sh)-$(date +'%Y%m%d')"

# Dump before
tempf=$(mktemp -t ${tempfpfx}-before-XXXXX.tmp)
dump_info > ${tempf}
echo "### before --> ${tempf}"

# Install
if ! rpm -q distribution-gpg-keys
then
  dnf -q -y install distribution-gpg-keys
fi

install_php ${remiv} ${phpv} \
 cli common fpm pear devel

if ! [ "${MINIMUL}" = '1' ]
then
  install_php ${remiv} ${phpv} \
   bcmath intl mbstring mysqlnd pdo \
   pecl-igbinary pecl-imagick-im7 pecl-memcache pecl-memcached \
   pecl-redis pecl-geoip pecl-imagick-im7
fi

# Register alternative
alternatives \
 --install /usr/bin/php         php         ${remidir}/root/usr/bin/php      20 \
 --slave   /usr/bin/pear        pear        ${remidir}/root/usr/bin/pear        \
 --slave   /usr/bin/pecl        pecl        ${remidir}/root/usr/bin/pecl        \
 --slave   /usr/bin/phar.phar   phar        ${remidir}/root/usr/bin/phar.phar   \
 --slave   /usr/bin/phpize      phpize      ${remidir}/root/usr/bin/phpize      \
 --slave   /usr/bin/php-cgi     php-cgi     ${remidir}/root/usr/bin/php-cgi     \
 --slave   /usr/bin/php-config  php-config  ${remidir}/root/usr/bin/php-config  \
 --slave   /etc/php.ini         php-ini     /etc/opt/remi/php${phpv}/php.ini    \
 --slave   /var/log/php-fpm     php-log     /var/opt/remi/php${phpv}/log/php-fpm/

# Set php-timezone
if grep -q -E '^;date\.timezone\s+=' /etc/php.ini
then
  sed --follow-symlinks -i.bak -E \
   '/;date\.timezone\s+=/s/^;//; /^date\.timezone\s+=/s/$/ "Asia\/Tokyo"/' \
    /etc/php.ini
fi

# Change log file path
readonly etcd="/etc/opt/remi/php${phpv}"

for f in ${etcd}/php-fpm.d/www.conf ${etcd}/php-fpm.conf
do
  sed --follow-symlinks -i.bak -E \
   '/^(slowlog|php_admin_value|error_log)[^=]+=.+\/.+\.log$/s#/.+/(.+)$#/var/log/php-fpm/\1#' \
    ${f}
done

# Register php-fpm as an alias
mkdir /etc/systemd/system/php${phpv}-php-fpm.service.d || true

cat << 'EOF' >> /etc/systemd/system/php${phpv}-php-fpm.service.d/override.conf
[Install]
Alias=php-fpm.service
EOF

# Add file-context
semanage fcontext -d -t httpd_log_t /var/log/php-fpm || true
semanage fcontext -a -t httpd_log_t /var/log/php-fpm
restorecon -Rv /var/log/

# Reset systemd
systemctl daemon-reload
systemctl enable --now php${phpv}-php-fpm

# Dump after
tempf=$(mktemp -t ${tempfpfx}-after-XXXXX.tmp)
dump_info > ${tempf}
echo "### after --> ${tempf}"

# Show Information
alternatives --display php

php-config --prefix
ls -l /etc/php.ini
ls -l /var/log/php-fpm

grep -r --exclude='*.bak' -E '^[^;].+\.log$' /etc/opt/remi/

exit 0


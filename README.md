# al2023-remi-php

Add remi repository to AWS EC2 instance Amazon Linux 2023 and install php versions 5.6, 7.x, 8.0, 8.1.  

install
```
# cp al2023-f34-remi34.repo /etc/yum.repos.d/
# sh al2023-remi-php-add.sh 72
```

uninstall
```
# sh al2023-remi-php-del.sh
# rm /etc/yum.repos.d/al2023-f34-remi34.repo
```

At your own risk.

Note: For versions 8.2 and later, please use the dnf command for regular installation.

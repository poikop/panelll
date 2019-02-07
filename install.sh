#!/bin/sh
LOG_PIPE=log.pipe
rm -f LOG_PIPE
mkfifo ${LOG_PIPE}
LOG_FILE=log.file
rm -f LOG_FILE
tee < ${LOG_PIPE} ${LOG_FILE} &

exec  > ${LOG_PIPE}
exec  2> ${LOG_PIPE}


Infon() {
	printf "\033[1;32m$@\033[0m"
}
Info()
{
	Infon "$@\n"
}
Error()
{
	printf "\033[1;31m$@\033[0m\n"
}
Error_n()
{
	Error "- - - $@"
}
Error_s()
{
	Error "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
log_s()
{
	Info "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
log_n()
{
	Info "- - - $@"
}
log_t()
{
	log_s
	Info "- - - $@"
	log_s
}
install_gamepl()
{
	Info "Здравствуйте, данный скрипт установит GamePL за Вас!"
	read -p "Пожалуйста, введите домен:" DOMAIN
	log_t "Start Install GamePL"
	log_t "Update"
	apt-get update
	log_t "Install packages"
	apt-get install -y apt-utils
	apt-get install -y pwgen
	apt-get install -y dialog
	MYPASS=$(pwgen -cns -1 20)
	MYPASS2=$(pwgen -cns -1 20)
	OS=$(lsb_release -s -i -c -r | xargs echo |sed 's; ;-;g' | grep Ubuntu)
	if [ "$OS" = "" ]; then
		log_t "Add repository"
		echo "deb http://packages.dotdeb.org wheezy-php55 all">"/etc/apt/sources.list.d/dotdeb.list"
		echo "deb-src http://packages.dotdeb.org wheezy-php55 all">>"/etc/apt/sources.list.d/dotdeb.list"
		wget http://www.dotdeb.org/dotdeb.gpg
		apt-key add dotdeb.gpg
		rm dotdeb.gpg
		log_t "Update"
		apt-get update
	fi
	log_t "Upgrade"
	apt-get upgrade -y
	echo mysql-server mysql-server/root_password select "$MYPASS" | debconf-set-selections
	echo mysql-server mysql-server/root_password_again select "$MYPASS" | debconf-set-selections
	log_t "Install packages"
	apt-get install -y apache2 php5 php5-dev cron unzip sudo php5-curl php5-memcache php5-json memcached mysql-server libapache2-mod-php5
	if [ "$OS" = "" ]; then
		apt-get install -y php5-ssh2
	else
		apt-get install -y  libssh2-php
	fi
	echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYPASS" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/app-pass password $MYPASS" |debconf-set-selections
	echo "phpmyadmin phpmyadmin/app-password-confirm password $MYPASS" | debconf-set-selections
	echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
	apt-get install -y phpmyadmin
	STRING=$(apache2 -v | grep Apache/2.4)
	if [ "$STRING" = "" ]; then
		FILE='/etc/apache2/conf.d/gamepl'
		echo "<VirtualHost *:80>">$FILE
		echo "ServerName $DOMAIN">>$FILE
		echo "DocumentRoot /var/gamepl">>$FILE
		echo "<Directory /var/gamepl/>">>$FILE
		echo "Options Indexes FollowSymLinks MultiViews">>$FILE
		echo "AllowOverride All">>$FILE
		echo "Order allow,deny">>$FILE
		echo "allow from all">>$FILE
		echo "</Directory>">>$FILE
		echo "ErrorLog \${APACHE_LOG_DIR}/error.log">>$FILE
		echo "LogLevel warn">>$FILE
		echo "CustomLog \${APACHE_LOG_DIR}/access.log combined">>$FILE
		echo "</VirtualHost>">>$FILE
	else
		FILE='/etc/apache2/conf-enabled/gamepl.conf'
		cd /etc/apache2/sites-available
		sed -i "/Listen 80/d" *
		cd ~
		echo "Listen 80">$FILE
		echo "<VirtualHost *:80>">$FILE
		echo "ServerName $DOMAIN">>$FILE
		echo "DocumentRoot /var/gamepl">>$FILE
		echo "<Directory /var/gamepl/>">>$FILE
		echo "AllowOverride All">>$FILE
		echo "Require all granted">>$FILE
		echo "</Directory>">>$FILE
		echo "ErrorLog \${APACHE_LOG_DIR}/error.log">>$FILE
		echo "LogLevel warn">>$FILE
		echo "CustomLog \${APACHE_LOG_DIR}/access.log combined">>$FILE
		echo "</VirtualHost>">>$FILE
	fi
	log_t "Enable modules Apache2"
	a2enmod rewrite
	a2enmod php5
	log_t "Install Ioncube"
	wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip
	unzip ioncube_loaders_lin_x86-64.zip
	cp ioncube/ioncube_loader_lin_5.5.so /usr/lib/php5/20121212/ioncube_loader_lin_5.5.so
	rm -R ioncube*
	echo "zend_extension=ioncube_loader_lin_5.5.so">>"/etc/php5/apache2/php.ini"
	echo "zend_extension=ioncube_loader_lin_5.5.so">>"/etc/php5/cli/php.ini"
	(crontab -l ; echo "*/5 * * * * cd /var/gamepl/;php5 cron.php") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	chown root:crontab /var/spool/cron/crontabs/root
	log_t "Service restart"
	service cron restart
	service apache2 restart
	log_t "install GamePL to dir /var/gamepl"
	mkdir /var/gamepl/
	cd /var/gamepl/
	wget http://aviras.ru/install.txt
	mv install.txt install.php
	cd ~
	chown -R www-data:www-data /var/gamepl/
	chmod -R 777 /var/gamepl/
	STATUS=$(cd /var/gamepl/;php5 install.php install $DOMAIN $MYPASS $MYPASS2)
	chown -R www-data:www-data /var/gamepl/
	chmod -R 770 /var/gamepl/
	rm -f /var/gamepl/install.php
	log_t "End install GamePL"
	if [ "$STATUS" = "100021" ]; then
		log_s
		log_n "Панель управления GamePL установлена!"
		log_n ""
		log_n "Root пароль от MySQL: $MYPASS"
		log_n ""
		log_n "Ссылка на GamePL: http://$DOMAIN"
		log_n ""
		log_n "Данные для входа:"
		log_n "Логин: install@gamepl.ru"
		log_n "Пароль: $MYPASS2"
		log_s
	else
		Error_s
		Error_n "ERROR: $STATUS"
		Error_n "Не удалось установить панель управления, попробуйте установить все сами!"
		Error_n "Root пароль от MySQL: $MYPASS"
		Error_s
	fi
	Info
	log_t "Добро пожаловать в установочное меню GamePL v.7"
	Info "1  -  Настроить машину под игры"
	Info "2  -  Установить игры"
	Info "0  -  Выход"
	Info
	read -p "Пожалуйста, введите номер меню:" case
	case $case in
		1) configure_box;;   
		2) install_games;;
		0) exit;;
	esac
}
install_games()
{
	upd
	clear
	Info
	log_t "Список доступных игр"
	Info "- 1  -  Установить SteamCMD[На новой машине обязательно!]"
	Info "- 2  -  Counter-Strike: 1.6"
	Info "- 3  -  Counter-Strike: Source"
	Info "- 4  -  Counter-Strike: Source v34"
	Info "- 5  -  Counter-Strike: GO"
	Info "- 6  -  Half-Life: Deathmatch"
	Info "- 7  -  Day of Defeat: Source"
	Info "- 8  -  Team Fortress 2"
	Info "- 9  -  Garry's Mod"
	Info "- 10 -  Left 4 Dead 2"
	Info "- 11 -  Minecraft"
	Info "- 12 -  Killing Floor"
	Info "- 13 -  GTA: Multi Theft Auto"
	Info "- 14 -  GTA: San Andreas Multiplayer"
	Info "- 15 -  GTA: Criminal Russia MP"
	Info "- 0  -  В главное меню"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню:" case
	case $case in
		1) 
			mkdir -p /host/
			mkdir -p /host/servers
			mkdir -p /host/servers/cmd
			cd /host/servers/cmd/
			wget http://media.steampowered.com/client/steamcmd_linux.tar.gz
			tar xvzf steamcmd_linux.tar.gz
			rm steamcmd_linux.tar.gz
			install_games
		;;   
		2)
			apt-get install -y zip unzip
			mkdir /host/servers/cs/
			cd /host/servers/cs/
			wget http://mc.aviras.ru/dl/cs.zip
			unzip cs.zip
			rm cs.zip
			install_games
		;;
		3)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/css/ +app_update 232330 validate +quit
			install_games
		;;
		4)
			apt-get install -y zip unzip
			mkdir /host/servers/css34/
			cd /host/servers/css34/
			wget http://mc.aviras.ru/dl/css34.zip
			unzip css34.zip
			rm css34.zip
			install_games
		;;
		5)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/csgo/ +app_update 740 validate +quit
			install_games
		;;
		6)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/hldm/ +app_update 232370 validate +quit
			install_games
		;;
		7)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/dods/ +app_update 232290 validate +quit
			install_games
		;;
		8)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/tf2/ +app_update 232250 validate +quit
			install_games
		;;
		9)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/gm/ +app_update 4020 validate +quit
			install_games
		;;
		10)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/l4d2/ +app_update 222860 validate +quit
			install_games
		;;
		11)
			mkdir /host/servers/mc/
			cd /host/servers/mc/
			wget http://mc.aviras.ru/dl/craftbukkit.jar
			install_games
		;;
		12)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/kf/ +app_update 215360 validate +quit
			install_games
		;;
		13)
			apt-get install -y zip unzip
			mkdir /host/servers/mta/
			cd /host/servers/mta/
			wget http://mc.aviras.ru/dl/mta.zip
			unzip mta.zip
			rm mta.zip
			install_games
		;;
		14)
			apt-get install -y zip unzip
			mkdir /host/servers/samp/
			cd /host/servers/samp/
			wget http://mc.aviras.ru/dl/samp.zip
			unzip samp.zip
			rm samp.zip
			install_games
		;;
		15)
			apt-get install -y zip unzip
			mkdir /host/servers/crmp/
			cd /host/servers/crmp/
			wget http://mc.aviras.ru/dl/crmp.zip
			unzip crmp.zip
			rm crmp.zip
			install_games
		;;
		0) menu;;
	esac
}
install_fastdl()
{
	if [ "$@" = "1" ]; then
		apt-get install -y apache2-mpm-itk php5
		STRING=$(apache2 -v | grep Apache/2.4)
		mkdir /etc/apache2/fastdl
		if [ "$STRING" = "" ]; then
			echo "Include /etc/apache2/fastdl/*.conf">>"/etc/apache2/apache2.conf"
		else
			echo "IncludeOptional fastdl/*.conf">>"/etc/apache2/apache2.conf"
		fi
		service apache2 restart
	else
		apt-get install -y nginx
		mkdir /etc/nginx/fastdl
		echo "server {">"/etc/nginx/sites-enabled/fastdl.conf"
		echo "listen 80 default;">>"/etc/nginx/sites-enabled/fastdl.conf"
		echo "include /etc/nginx/fastdl/*;">>"/etc/nginx/sites-enabled/fastdl.conf"
		echo "}">>"/etc/nginx/sites-enabled/fastdl.conf"
		sed -i 's/user www-data;/user root;/g' "/etc/nginx/nginx.conf"
		service nginx restart
	fi
}
install_ftp()
{
	apt-get install -y pure-ftpd-common pure-ftpd
	echo "yes" > /etc/pure-ftpd/conf/CreateHomeDir
	echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
	echo "yes" > /etc/pure-ftpd/conf/ChrootEveryone
	echo "yes" > /etc/pure-ftpd/conf/VerboseLog
	echo "yes" > /etc/pure-ftpd/conf/IPV4Only
	echo "100" > /etc/pure-ftpd/conf/MaxClientsNumber
	echo "8" > /etc/pure-ftpd/conf/MaxClientsPerIP
	echo "no" > /etc/pure-ftpd/conf/DisplayDotFiles 
	echo "15" > /etc/pure-ftpd/conf/MaxIdleTime
	echo "16" > /etc/pure-ftpd/conf/MaxLoad
	echo "50000 50300" > /etc/pure-ftpd/conf/PassivePortRange
	rm /etc/pure-ftpd/conf/PAMAuthentication /etc/pure-ftpd/auth/70pam 
	ln -s ../conf/PureDB /etc/pure-ftpd/auth/45puredb
	pure-pw mkdb
	/etc/init.d/pure-ftpd restart
	screen -dmS ftp_s pure-pw useradd root -u www-data -g www-data -d /host -N 15000
	sleep 5
	screen -S ftp_s -p 0 -X stuff '123$\n';
	sleep 5
	screen -S ftp_s -p 0 -X stuff '123$\n';
	sleep 5
	pure-pw mkdb
	/etc/init.d/pure-ftpd restart
	pure-pw userdel root
	pure-pw mkdb
	/etc/init.d/pure-ftpd restart
}
install_java()
{
	echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
	echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
	echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee -a /etc/apt/sources.list
	echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee -a /etc/apt/sources.list
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
	apt-get update
	apt-get install -y oracle-java7-installer
}
install_base()
{
	apt-get install -y ssh sudo screen cpulimit zip unzip
	OS=$(lsb_release -s -i -c -r | xargs echo |sed 's; ;-;g' | grep Ubuntu)
	if [ "$OS" = "" ]; then
		sudo dpkg --add-architecture i386
		sudo apt-get update 
		sudo apt-get install -y ia32-libs
	else
		cd /etc/apt/sources.list.d
		echo "deb http://old-releases.ubuntu.com/ubuntu/ raring main restricted universe multiverse" >ia32-libs-raring.list
		apt-get update
		apt-get install -y ia32-libs

	fi
}
configure_box()
{
	upd
	clear
	Info
	log_t "Добро пожаловать в меню настройки сервера"
	Info "- 1  -  Установить основные пакеты"
	Info "- 2  -  Настроить FastDL на Apache"
	Info "- 3  -  Настроить FastDL на Nginx"
	Info "- 4  -  Установить FTP сервер"
	Info "- 5  -  Установить Java"
	Info "- 0  -  В главное меню"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню:" case
	case $case in
		1) install_base;;
		2) install_fastdl "1";;
		3) install_fastdl "2";;
		4) install_ftp;;
		5) install_java;;
		0) menu;;
	esac
	configure_box
}
UPD="0"
upd()
{
	if [ "$UPD" = "0" ]; then
		apt-get update
		UPD="1"
	fi
}
menu()
{
	clear
	Info
	log_t "Добро пожаловать в установочное меню GamePL v.7"
	Info "- 1  -  Установить GamePL"
	Info "- 2  -  Настроить машину под игры"
	Info "- 3  -  Установить игры"
	Info "- 0  -  Выход"
	log_s
	Info
	read -p "Пожалуйста, введите пункт меню:" case
	case $case in
		1) install_gamepl;;   
		2) configure_box;;   
		3) install_games;;
		0) exit;;
	esac
}
menu

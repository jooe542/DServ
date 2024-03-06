#!/bin/bash

# szinek
cDef="\e[39m"
cGreen="\e[92m"
cCyan="\e[36m"
cYellow="\e[93m"
cMagenta="\e[35m"
cRed="\e[31m"

confDir="/etc/dserv/config"
appsDir="/etc/dserv/apps"

opDbConf="host\top_gl\topenproject\t127.0.0.1/24\tscram-sha-256 #DServ OP\n"

setuplog="${cMagenta}------- A telepites eredmenye -------${cDef}\r\n"

# Kiechozza a megadott uzenetet a megadott szinnel
# $1 szin
# $2 uzenet
meco() {
	color=$1
	msg=$2
	echo -e "${color}${msg}${cDef}"
}

# Letrehoz egy console-log bejegyzest
# $1 szin
# $2 szint
# $3 uzenet
# $4 output
log_entry() {
	color=$1
	level=$2
	msg=$3
	echo "${color}| ${level} | ${msg}${cDef}\r\n"
}

# Alapcsomagok telepitese
install_base() {
	cecho "..p**| info | Install basic tools.**p.."

	apt-get install -y net-tools iproute2 wget tree htop tmux vim

	newEntry=$(log_entry $cGreen "success" "Alapcsomag - Telepites befejezve")
	setuplog+=$newEntry
	echo -e $newEntry
}

# Telepiti a certbotot
install_certbot() {
	meco $cMagenta "| info | Certbot telepitese"

	apt-get install -y certbot python3-certbot-nginx

	newEntry=$(log_entry $cGreen "success" "Certbot - Telepites befejezve")
	setuplog+=$newEntry
	echo -e $newEntry
}

# Telepiti a dotnet6-ot
install_dotnet() {
	cecho "..p**| info | Install .NET 6 and 8**p.."

	apt-get -y install dotnet6 dotnet8

	newEntry=$(log_entry $cGreen "success" ".NET 6 - Telepites befejezve")
	setuplog+=$newEntry
	echo -e $newEntry
}

# Docker telepitese
# Forras: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
install_docker() {
	apt list --installed | grep -q ^docker
	if [ $? -eq 0 ]; then
		cecho "..wDocker already installed!w..\n"
		return 1
	fi

	meco $cMagenta "| info | Docker engine telepitese"

	meco $cCyan "| 1 | Meglevo fuggosegek torlese"

	for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove $pkg; done

	meco $cCyan "| 2 | Repo beallitasa"
	apt-get update
	apt-get install -y ca-certificates curl gnupg

	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	chmod a+r /etc/apt/keyrings/docker.gpg

	echo \
		"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
		tee /etc/apt/sources.list.d/docker.list >/dev/null

	# Install docker engine
	meco $cCyan "| 3 | Telepites"
	apt-get update
	apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	#docker run hello-world

	newEntry=$(log_entry $cGreen "success" "Docker - Telepites befejezve")
	setuplog+=$newEntry
	echo -e $newEntry
}

# Virtualmin telepitese
# Forras: https://www.virtualmin.com/download/
install_virtualmin() {
	meco $cMagenta "| info | virtualmin telepitese"

	meco $cCyan "| 1 | virtualmin letoltese"

	if [ ! -d files ]; then
		mkdir files
	fi

	cd files
	wget https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh

	meco $cCyan "| 1 | virtualmin telepitese"
	sh virtualmin-install.sh -b LEMP --force
	cd ..

	newEntry=$(log_entry $cGreen "success" "virtualmin - Telepites befejezve")
	setuplog+=$newEntry
	echo -e $newEntry
}

# nginx telepitese
# Forras: https://nginx.org/en/linux_packages.html#Ubuntu
install_nginx() {
	apt list --installed | grep -q ^nginx
	if [ $? -eq 0 ]; then
		echo "..wNGINX already installed!w..\n"
		return 1
	fi

	cecho "..p**| info | Install NGINX**p.."
	cecho "..c| 1 | Setup PPAc.."

	apt-get install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
	curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor |
		tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

	gpgOut=$(gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg)
	echo $gpgOut

	case "$gpgOut" in
	*573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62*)
		cecho "..g| info | Fingerprint is validg.."
		;;
	*)
		cecho "..y| warning | Fingerprint is not valid!y.."
		newEntry=$(log_entry $cYellow "warning" "Nginx - Az ujjlenyomat nem egyezik")
		setuplog+=$newEntry
		;;
	esac

	echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" |
		tee /etc/apt/sources.list.d/nginx.list

	echo "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" |
		tee /etc/apt/preferences.d/99nginx

	cecho "..c| 2 | Installc.."

	apt-get update
	apt-get install -y nginx

	newEntry=$(log_entry $cGreen "success" "Nginx - Install success")
	setuplog+=$newEntry
	echo -e $newEntry
}

# Install PostgreSQL
# return 1 - Already installed
install_postgresql() {
	apt list --installed | grep -q ^postgresql
	if [ $? -eq 0 ]; then
		echo "..wPostgreSQL already installed!w..\n"
		return 1
	fi

	apt-get -y install postgresql &&
		cp "${confDir}/pg_hba.conf" /etc/postgresql/14/main/pg_hba.conf &&
		cp "${confDir}/postgresql.conf" /etc/postgresql/14/main/postgresql.conf &&
		service postgresql restart &&
		# Admin user letrehozasa
		psql -U postgres -c "create role dserv with superuser login password 'D53rvSm1L3y3D1710n';"
}

# OpenSSH server telepitese
install_openssh_server() {
	apt-get -y install openssh-server
}

install_openproject() {
	cecho "..cCheck PostgreSQL...c..\n"
	install_postgresql

	cecho "..cCheck Docker...c..\n"
	install_docker

	cecho "..cCheck NGINX...c..\n"
	install_nginx

	cecho "..cSetup database...c..\n"
	pghome="/etc/postgresql/14/main"

	if ! grep -q "${opDbConf}" "${pghome}/pg_hba.conf"; then
		#	if [ $? -gt 0 ]; then
		psql -U postgres -c "create role openproject with login password 'DAJiUM5Z9QI6XegkZopKm';"
		psql -U postgres -c "create database op_gl with owner openproject encoding UTF8;"

		echo -e "${opDbConf}" >>"${pghome}/pg_hba.conf"
		service postgresql restart
	fi

	cecho "..cLoad Docker image **op_gl.tar**...c.."
	#	docker load -i "${appsDir}/op_gl.tar"

	if ! docker load -i "${appsDir}/op_gl.tar"; then
		#	if [ $? -gt 0 ]; then
		cecho "..r**Failed!**r.."
		exit 3
	fi

	cecho "..cStarting Docker containers...c..\n"
	docker compose -f "${confDir}/compose/op_gl.yml" up -d

	cecho "..g**Everything is up!**g..\n"
	return 0
}

install_php() {
	apt -y install ca-certificates apt-transport-https software-properties-common lsb-release
	add-apt-repository ppa:ondrej/php -y
	apt -y update && apt -y upgrade
	apt -y install php8.2 php8.2-fpm php8.2-cli

	apt -y install php-bz2 php-common php-curl php-gd php-imagick php-intl php-mbstring \
		php-memcache php-mysql php-pgsql php-xml php-zip php8.2-bz2 php8.2-cli php8.2-common \
		php8.2-curl php8.2-fpm php8.2-gd php8.2-imagick php8.2-intl php8.2-mbstring \
		php8.2-memcache php8.2-mysql php8.2-opcache php8.2-pgsql php8.2-readline php8.2-xml \
		php8.2-zip

	service php8.2-fpm start
}

install_gitlab() {
	cecho "..p--- Install GitLab ---p..\n"
	cecho "..c**Check NGINX...**c..\n"
	install_nginx

	cecho "..c**| 1 | Pull GitLab Docker image**c..\n"
	if ! docker pull gitlab/gitlab-ce:latest; then
		cecho "..r**Error: Failed to pull GitLab Docker image!**r..\n"
		return 1
	fi

	cecho "..c**| 2 | Setting up NGINX reverse proxy config**c..\n"
	read -r -p "Enter the hostname for GitLab (e.g., gitlab.example.com): " hostname
	hostname=${hostname,,}
	hostname=$(echo "${hostname}" | sed "s/\./\\./g")

	sed -r "s/^[ \t]*server_name.*$/\tserver_name ${hostname};/g" "${confDir}/ng_gitlab.conf" >/etc/nginx/conf.d/ng_gitlab.conf

	cecho "..c**| 3 | Run GitLab Docker container**c..\n"

	if ! docker compose -f "${confDir}/compose/gitlab.yml" up -d; then
		cecho "..r**Error: Failed to start GitLab Docker!**r..\n"
		return 2
	fi

	cecho "..g**GitLab Docker container started successfully!**g..\n"
}

# Installal/beallit mindent is.
install_all() {
	install_base
	install_virtualmin
	install_dotnet
	install_nginx
	install_docker
	install_gitlab
	echo -e $setuplog
}

# Delete GitLab
uninstall_gitlab() {
	cecho "..c**Are you sure you want to uninstall GitLab Docker? (y/n)**c..\n"
	read -r confirmation

	case "$confirmation" in
	[yY] | [yY][eE][sS])
		if docker compose "${confDir}/compose/gitlab.yml down"; then
			cecho "..g**GitLab Docker container stopped.**g..\n"
		else
			cecho "..r**Failed to stop GitLab Docker container.**r..\n"
			return 11
		fi

		if docker image rm gitlab; then
			cecho "..g**GitLab Docker container removed.**g..\n"
		else
			cecho "..r**Failed to remove GitLab Docker container.**r..\n"
			return 12
		fi

		if rm -f /etc/nginx/conf.d/ng_gitlab.conf; then
			cecho "..g**NGINX config file removed.**g..\n"
		else
			cecho "..r**Failed to remove NGINX config file.**r..\n"
			return 13
		fi

		cecho "..g**GitLab Docker uninstallation completed.**g..\n"
		return 0
		;;
	[nN] | [nN][oO])
		cecho "..r**GitLab Docker uninstallation cancelled.**r..\n"
		return 2
		;;
	*)
		cecho "..y**Invalid option. Exiting.**y..\n"
		return 3
		;;
	esac
}

# Telepiti a certbotot
uninstall_certbot() {
	meco $cMagenta "| info | Certbot torlese"

	apt-get autoremove -y certbot
	apt-get purge -y certbot
	apt-get autoremove -y python3-certbot-nginx
	apt-get purge -y python3-certbot-nginx

	meco $cCyan "| info | Kesz"
}

uninstall_dotnet() {
	meco $cMagenta "| info | .NET 6 torlese"

	apt-get -y autoremove dotnet6
	apt-get -y purge dotnet6

	meco $cCyan "| info | Kesz"
}

# Torli a docker-t valamint a telepitese soran letrehozott mappakat, rendszermodositasokat.
uninstall_docker() {
	meco $cMagenta "| info | Docker beallitasok torlese"

	apt-get -y autremove docker
	apt-get -y purge docker

	meco $cCyan "| info | Kesz"
}

# Virtualmin torlese
# Forras: https://www.virtualmin.com/documentation/installation/uninstalling/
uninstall_virtualmin() {
	meco $cMagenta "| info | virtualmin torlese"

	if [ -d files ]; then
		cd files
		if [ -a virtualmin-install.sh ]; then
			sh virtualmin-install.sh --uninstall
		else
			meco $cRed "| error | A virtualmin telepitoje hianyzik!"
		fi
		cd ..
	else
		meco $cRed "| error | A 'files' konyvtar hianyzik!"
		meco $cRed "| error | A virtualmin telepitoje nem erheto el!"
	fi

	meco $cCyan "| info | Kesz"
}

# Torli az nginx-t valamint a telepitese soran letrehozott mappakat, rendszermodositasokat.
uninstall_nginx() {
	meco $cMagenta "| info | Nginx beallitasok torlese"

	systemctl status stop nginx
	apt-get -y autoremove nginx
	apt-get -y purge nginx

	if [ -d /etc/nginx ]; then
		rm -r /etc/nginx
	fi

	meco $cCyan "| info | Kesz"
}

# PostgreSQL torlese
uninstall_postgresql() {
	apt-get -y autoremove postgresql
	apt-get -y purge postgresql
}

# OpenSSH server torlese
uninstall_openssh_server() {
	apt-get -y autoremove openssh-server
	apt-get -y purge openssh-server
}

uninstall_openproject() {
	cecho "..w**Every data with the database will be erase!**w..\n"
	cecho "..w**This action also includes the database.**w..\n"
	read -r -p "Are you sure? [y/n]" response
	response=${response,,}

	if [ "${response}" != "yes" ] && [ "${response}" != "y" ]; then
		return 1
	fi

	echo "..cDelete Docker containers and images...c..\n"
	docker compose -f "${confDir}/compose/op_gl.yml" down
	docker image rm op_gl

	cecho "..cDelete PostgreSQL settings and database...c..\n"
	if ! grep -q "${opDbConf}" "${pghome}/pg_hba.conf"; then
		sed "s/${opDbConf}//g" "${pghome}/pg_hba.conf"
		psql -U postgres -c "drop database op_gl with (force);"
		psql -U postgres -c "drop user openproject;"
		service postgresql restart
	fi

	cecho "..gUninstall completed!g..\n"
	return 0
}

uninstall_php() {
	service php8.2-fpm stop
	apt -y autoremove php*
	apt -y purge php*
}

# Torol mindent is.
uninstall_all() {
	meco $cMagenta "DServ programok/beallitasok torlese"

	uninstall_virtualmin
	uninstall_dotnet
	uninstall_nginx
	uninstall_docker

	meco $cGreen "DServ programok/beallitasok torlese befejezve."
}

install() {
	case $1 in
	all)
		install_all
		;;
	base)
		install_base
		;;
	dotnet)
		install_dotnet
		;;
	nginx)
		install_nginx
		;;
	postgresql)
		install_postgresql
		;;
	docker)
		install_docker
		;;
	virtualmin)
		install_virtualmin
		;;
	openssh-server)
		install_openssh_server
		;;
	openproject)
		install_openproject
		;;
	certbot)
		install_certbot
		;;
	php)
		install_php
		;;
	gitlab)
		install_gitlab_docker
		;;
	esac
}

uninstall() {
	case $1 in
	all)
		uninstall_all
		;;
	dotnet)
		uninstall_dotnet
		;;
	nginx)
		uninstall_nginx
		;;
	postgresql)
		uninstall_postgresql
		;;
	docker)
		uninstall_docker
		;;
	virtualmin)
		uninstall_virtualmin
		;;
	openssh-server)
		uninstall_openssh_server
		;;
	openproject)
		uninstall_openproject
		;;
	certbot)
		uninstall_certbot
		;;
	php)
		uninstall_php
		;;
	gitlab)
		gitlab_uninstall
		;;
	esac
}

case $1 in
install)
	install $2
	;;
uninstall)
	uninstall $2
	;;
*)
	echo "DO NOT USE THIS COMMAND ALONE!!! You are not Lucky Luke. Use only the 'dserv'!"
	;;
esac

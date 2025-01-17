confDir="/etc/dserv/config"

configure_timezone() {
    ln -fs /usr/share/zoneinfo/Europe/Budapest /etc/localtime
    DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
    dpkg-reconfigure --frontend noninteractive tzdata
}

configure_aliases() {
    echo "$(cat ${confDir}/aliases.txt)" >> /etc/bash.bashrc    
}

case $1 in 
    timezone)
        configure_timezone
        ;;
    aliases)
        configure_aliases
        ;;
    *)
        echo "DO NOT USE THIS COMMAND ALONE!!! You are not Lucky Luke. Use only the 'dserv'!"
        ;;
esac
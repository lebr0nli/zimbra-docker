#!/bin/sh

set -ex

## Preparing all the variables like IP, Hostname, etc, all of them from the container
HOSTNAME=$(hostname)
DOMAIN=$(hostname -d)
CONTAINERIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
SYSTEMMEMORY=$(($(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 / 1024))

## Installing the DNS Server ##
echo "Configuring DNS Server"
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.old
cat << EOF >> /etc/dnsmasq.conf
server=9.9.9.9
server=149.112.112.112
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=8.8.4.4

# trust-anchor is a DS record (ie a hash of the root Zone Signing Key)
# If was downloaded from https://data.iana.org/root-anchors/root-anchors.xml
trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D
dnssec
dnssec-check-unsigned

no-resolv
listen-address=127.0.0.1
domain=$DOMAIN
mx-host=$DOMAIN,$HOSTNAME,0
address=/$HOSTNAME/$CONTAINERIP
bind-interfaces
bogus-priv
domain-needed
stop-dns-rebind
rebind-localhost-ok

cache-size=2000
EOF
sudo service dnsmasq restart

if [ -d /opt/zimbra-install/ ]; then
    echo "Creating the Zimbra Collaboration Config File"
    touch /opt/zimbra-install/installZimbraScript
    cat << EOF > /opt/zimbra-install/installZimbraScript
AVDOMAIN="$DOMAIN"
AVUSER="admin@$DOMAIN"
CREATEADMIN="admin@$DOMAIN"
CREATEADMINPASS="$PASSWORD"
CREATEDOMAIN="$DOMAIN"
DOCREATEADMIN="yes"
DOCREATEDOMAIN="yes"
DOTRAINSA="yes"
ENABLEDEFAULTBACKUP="yes"
EXPANDMENU="no"
HOSTNAME="$HOSTNAME"
HTTPPORT="8080"
HTTPPROXY="TRUE"
HTTPPROXYPORT="80"
HTTPSPORT="8443"
HTTPSPROXYPORT="443"
IMAPPORT="7143"
IMAPPROXYPORT="143"
IMAPSSLPORT="7993"
IMAPSSLPROXYPORT="993"
INSTALL_WEBAPPS="service zimlet zimbra zimbraAdmin"
JAVAHOME="/opt/zimbra/common/lib/jvm/java"
LDAPBESSEARCHSET="set"
LDAPAMAVISPASS="$PASSWORD"
LDAPPOSTPASS="$PASSWORD"
LDAPROOTPASS="$PASSWORD"
LDAPADMINPASS="$PASSWORD"
LDAPREPPASS="$PASSWORD"
LDAPBESSEARCHSET="set"
LDAPDEFAULTSLOADED="1"
LDAPHOST="$HOSTNAME"
LDAPPORT="389"
LDAPREPLICATIONTYPE="master"
LDAPSERVERID="2"
MAILBOXDMEMORY="1920"
MAILPROXY="TRUE"
MODE="https"
MYSQLMEMORYPERCENT="30"
ONLYOFFICEHOSTNAME="$HOSTNAME.$DOMAIN"
ONLYOFFICESTANDALONE="no"
POPPORT="7110"
POPPROXYPORT="110"
POPSSLPORT="7995"
POPSSLPROXYPORT="995"
PROXYMODE="https"
REMOVE="no"
RUNARCHIVING="no"
RUNAV="yes"
RUNCBPOLICYD="no"
RUNDKIM="yes"
RUNSA="yes"
RUNVMHA="no"
SERVICEWEBAPP="yes"
SMTPDEST="admin@$DOMAIN"
SMTPHOST="$HOSTNAME"
SMTPNOTIFY="yes"
SMTPSOURCE="admin@$DOMAIN"
SNMPNOTIFY="yes"
SNMPTRAPHOST="$HOSTNAME"
SPELLURL="http://$HOSTNAME:7780/aspell.php"
STARTSERVERS="yes"
STRICTSERVERNAMEENABLED="TRUE"
SYSTEMMEMORY="$SYSTEMMEMORY"
TRAINSAHAM="ham.account@$DOMAIN"
TRAINSASPAM="spam.account@$DOMAIN"
UIWEBAPPS="yes"
UPGRADE="yes"
USEKBSHORTCUTS="TRUE"
USESPELL="yes"
VERSIONUPDATECHECKS="TRUE"
VIRUSQUARANTINE="virus-quarantine.account@$DOMAIN"
ZIMBRA_REQ_SECURITY="yes"
ldap_bes_searcher_password="$PASSWORD"
ldap_dit_base_dn_config="cn=zimbra"
ldap_nginx_password="$PASSWORD"
mailboxd_directory="/opt/zimbra/mailboxd"
mailboxd_keystore="/opt/zimbra/mailboxd/etc/keystore"
mailboxd_keystore_password="$PASSWORD"
mailboxd_server="jetty"
mailboxd_truststore="/opt/zimbra/common/lib/jvm/java/lib/security/cacerts"
mailboxd_truststore_password="changeit"
postfix_mail_owner="postfix"
postfix_setgid_group="postdrop"
ssl_default_digest="sha256"
zimbraDNSMasterIP="8.8.4.4"
zimbraDNSTCPUpstream="no"
zimbraDNSUseTCP="yes"
zimbraDNSUseUDP="yes"
zimbraDefaultDomainName="$DOMAIN"
zimbraFeatureBriefcasesEnabled="Enabled"
zimbraFeatureTasksEnabled="Enabled"
zimbraIPMode="ipv4"
zimbraMailProxy="FALSE"
zimbraMtaMyNetworks="127.0.0.0/8 $CONTAINERIP/32 [::1]/128 [fe80::]/64"
zimbraPrefTimeZoneId="Asia/Taipei"
zimbraReverseProxyLookupTarget="TRUE"
zimbraVersionCheckInterval="1d"
zimbraVersionCheckNotificationEmail="admin@$DOMAIN"
zimbraVersionCheckNotificationEmailFrom="admin@$DOMAIN"
zimbraVersionCheckSendNotifications="TRUE"
zimbraWebProxy="TRUE"
zimbra_ldap_userdn="uid=zimbra,cn=admins,cn=zimbra"
zimbra_require_interprocess_security="1"
zimbra_server_hostname="$HOSTNAME"
INSTALL_PACKAGES="zimbra-core zimbra-ldap zimbra-logger zimbra-mta zimbra-snmp zimbra-store zimbra-apache zimbra-spell zimbra-convertd zimbra-memcached zimbra-proxy zimbra-onlyoffice"
EOF

    echo "Extracting files from the archive"
    tar xzvf /opt/zimbra-install/zcs.tgz -C /opt/zimbra-install/

    echo "Update package cache"
    apt update

    echo "Installing Zimbra Collaboration just the Software"
    cd /opt/zimbra-install/zcs-* && ./install.sh -s < /opt/zimbra-install/installZimbra-keystrokes

    echo "Installing Zimbra Collaboration and injecting the configuration"
    /opt/zimbra/libexec/zmsetup.pl -c /opt/zimbra-install/installZimbraScript

    echo "Removing the installZimbraScript file"
    rm -rf /opt/zimbra-install/
else
    echo "Restarting the services"
    su - zimbra -c 'zmcontrol restart'

    if [ "$(su - zimbra -c 'postconf mynetworks' | grep -c "$CONTAINERIP")" -eq 0 ]; then
        echo "Container IP changed, updating zimbraMtaMyNetworks"
        su - zimbra -c "zmprov ms $HOSTNAME zimbraMtaMyNetworks '127.0.0.0/8 $CONTAINERIP/32 [::1]/128 [fe80::]/64'"
        su - zimbra -c 'postfix reload'
        su - zimbra -c 'postconf mynetworks'
    fi
fi

echo "You can access now to your Zimbra Collaboration Server"

# TODO: Maybe tail the logs of zimbra instead of sleep infinity
cd /opt/zimbra/
sh -c "trap : TERM INT; sleep infinity & wait"

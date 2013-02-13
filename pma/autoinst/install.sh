#!/bin/bash
# usage: $0 domain admin-email

G_HOSTNAME=$1
G_DATABASE=`echo "${G_HOSTNAME}" | sed -e 's/[\.-]/_/g'`

G_ADMIN_EMAIL=$2
G_INSTALL_OPTIONS=$3
#G_TARGET=NULL
G_TARGET="master"
G_SNSDIR=/var/www/sites
G_DBCONF_FILE=/var/www/sites/a3.xpne.info/pma/autoinst/db.conf
G_USED_DOMAIN_LIST_FILE=/var/www/sites/a3.xpne.info/pma/autoinst/used_domain_list.txt
G_EXEC_USER="admin"

function pne_log(){
  local msg=$1
  local type=$2

  if [ "${type}" == "" ]; then
    echo "${G_HOSTNAME} ${msg}"
  elif [ "${type}" == "info" ]; then
    echo "${G_HOSTNAME} ${msg}"
    logger ${G_HOSTNAME} "${msg}"
  elif [ "${type}" == "error" ]; then
    echo "${G_HOSTNAME} ${msg}" 2>&1
    logger ${G_HOSTNAME} "${msg}"
  fi
}

function is_not_root(){
  if [ `whoami` == "root" ]; then
    pne_log "user must not be root to execute this script" "error"
    exit 1;
  fi
  if [ `whoami` != "${G_EXEC_USER}" ]; then
    pne_log "user must be admin to execute this script" "error"
    exit 1;
  fi
}

function is_correct_options(){
  local len=$1

  if [ 2 -gt "${len}" ]; then
    pne_log "script argments number must be given 2, domain and admin-email" "error"
    exit 1
  fi
}

function check_domain_list(){
  local isExist=`grep ^$G_HOSTNAME $G_USED_DOMAIN_LIST_FILE`
  if [ "$isExist" != "" ]; then
    pne_log "$G_HOSTNAME is already used" "error"
    exit 1
  fi
}

# CONFFIlE must be follow format
# DBUSER=****
# DBPASS=****
# DBHOST= (optional)
# DBPORT= (optional)
# DBSOCK= (optional)
function load_db_conf(){
  pne_log "load db conf"

  if [ ! -e $G_DBCONF_FILE ]; then
    pne_log "database config file is not exist ${G_DBCONF_FILE}" "error"
    exit 1
  fi

  . $G_DBCONF_FILE

  G_DBUSER=$DBUSER
  G_DBPASS=$DBPASS

  if [ "${DBHOST}" != "" ]; then
    G_DBHOST=$DBHOST
  else
    G_DBHOST="localhost"
  fi

  if [ "${DBSOCK}" != "" ]; then
    G_DBSOCK=$DBSOCK
  else
    G_DBPORT=3306
    if [ "${DBPORT}" != "" ]; then
      G_DBPORT=$DBPORT
    fi
  fi
}

function create_password(){
  local len=$1
  local char='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890';
  local i=1

  while [ $i -le $len ]; do
    dm=$(( (RANDOM % ${#char}) ))
    PASS="${PASS}${char:${dm}:1}"
    i=$(( i+1 ))
  done

  echo $PASS
}

function get_pne_from_git(){
  local PNESRCREPOS=$1

  pne_log "src get from ${PNESRCREPOS} using git"

  cd $G_SNSDIR
  git clone $PNESRCREPOS $G_HOSTNAME
  if [ ! -e $G_HOSTNAME ]; then
    pne_log "Fail to get OpenPNE code" "error"
    exit 1
  fi
}

function get_pne_from_local(){
  local PNESRCREPOS=$1

  pne_log "src get from ${PNESRCREPOS} using cp"

  cd $G_SNSDIR
  cp -a $PNESRCREPOS $G_HOSTNAME
  if [ ! -e $G_HOSTNAME ]; then
    pne_log "Fail to get OpenPNE code" "error"
    exit 1
  fi
}


function set_pne_config(){
  cp config/ProjectConfiguration.class.php.sample config/ProjectConfiguration.class.php
  cp config/OpenPNE.yml.sample config/OpenPNE.yml
  sed -i "s/\#mail_envelope_from/mail_envelope_from/" ./config/OpenPNE.yml
  sed -i "s/smtp\.example\.com/${G_HOSTNAME}/" ./config/OpenPNE.yml
  sed -i "s/example\.com/${G_HOSTNAME}/" ./config/OpenPNE.yml

#  sed -i "s/\#RewriteBase/RewriteBase/" ./web/.htaccess
  echo "session_save_path: \"/var/lib/php/${G_HOSTNAME}\"" |  cat >> config/OpenPNE.yml
  ln -s "web" "public_html"
}

function ch_pne_ver(){
  cd $G_SNSDIR/$G_HOSTNAME
  git checkout ${G_TARGET}
}

function exec_pne_install(){
  local LOGFILE=$1

  echo $'mysql\n'${G_DBUSER}$'\n'${G_DBPASS}$'\n'${G_DBHOST}$'\n'${G_DBPORT}$'\n'${G_DATABASE}$'\n'${G_DBSOCK}$'\n' | ./symfony openpne:install > $LOGFILE
}

function install_pne(){
  pne_log "start install OpenPNE to ${G_SNSDIR}/${G_HOSTNAME}"

  local PNESRC=/opt/tejimaya/openpne/openpne3_gyoen.pne.jp
  LOGFILE=$G_DATABASE.log

  if [ -e "${G_SNSDIR}/${G_HOSTNAME}" ]; then
    pne_log "the dir ${G_SNSDIR}/${G_HOSTNAME} is already exist" "error"
    exit 1
  fi

  load_db_conf
  #get_pne_from_local $PNESRC
  get_pne_from_git $PNESRC
  ch_pne_ver
  set_pne_config
  exec_pne_install $LOGFILE
  LINE=`tail -n 1 $LOGFILE`
  if [ "${LINE}" != ">> installer installation is completed!" ]; then
    pne_log "Fail to install OpenPNE" "error"
    touch ${G_SNSDIR}/${G_HOSTNAME}/.FAIL_INSTALL_LOCK
    exit 1
  fi
}

function set_mail_conf(){
  pne_log "start set mail config"

  local ALIASNAME=${G_DATABASE}

  local virtualfile=/etc/postfix/virtual.openpne
  local isVirtualExist=`grep ${G_HOSTNAME} ${virtualfile}`

  if [ "$isVirtualExist" == "" ]; then
    cp $virtualfile /tmp/virtual.openpne.`date +%Y%m%d`
    cat >> $virtualfile <<EOF

# ${G_HOSTNAME} settings
${G_HOSTNAME}     anything
@${G_HOSTNAME}    ${ALIASNAME}
sns@${G_HOSTNAME} ${G_ADMIN_EMAIL}
EOF

    /usr/sbin/postmap $virtualfile
  fi

  local aliasfile=/etc/postfix/aliases.openpne
  local isAliasExist=`grep ${G_HOSTNAME} ${aliasfile}`


  if [ "$isAliasExist" == "" ]; then
    cp ${aliasfile} /tmp/aliases.openpne.`date +%Y%m%d`
    cat >> $aliasfile <<EOF

# ${G_HOSTNAME} setting
${ALIASNAME}: "| cd ${G_SNSDIR}/${G_HOSTNAME} ; /usr/bin/php ${G_SNSDIR}/${G_HOSTNAME}/symfony openpne:execute-mail-action"
EOF

    /usr/sbin/postalias $aliasfile
  fi
  #LINE=`ls -l /etc/aliases.db`
  #if [ "${LINE}" != ""]; then
  #  echo "echo test"
}

function set_cron_conf(){
  pne_log "start set cron config"

  local crontabfile=/tmp/crontab.admin.tmp.`date +%Y%m%d`

  crontab -l > $crontabfile

  local isExist=`grep ${G_HOSTNAME} ${crontabfile}`

  if [ "$isExist" == "" ]; then

    cat >> $crontabfile <<EOF

# ${G_HOSTNAME} settings
00 6 * * * cd ${G_SNSDIR}/${G_HOSTNAME}/bin ; sh send_daily_news.cron ${G_SNSDIR}/${G_HOSTNAME} /usr/bin/php
00 6 * * * cd ${G_SNSDIR}/${G_HOSTNAME}/bin ; sh birthday_mail.cron ${G_SNSDIR}/${G_HOSTNAME} /usr/bin/php
00 0 * * * cd ${G_SNSDIR}/${G_HOSTNAME} ; ./symfony opPMReport:totalall
EOF
    cat $crontabfile | crontab
  fi

  chmod -R 0755 ${G_SNSDIR}/${G_HOSTNAME}/bin/*.cron

# TODO: check to complete this method
}


function get_db_args(){
  local ARGS="$G_DATABASE --user=$G_DBUSER --password=$G_DBPASS --host=$G_DBHOST"
  if [ "${G_DBSOCK}" != "" ]; then
    ARGS="${ARGS} --socket=${G_DBSOCK}"
  elif [ "${G_DBPORT}" ]; then
    ARGS="${ARGS} --port=${G_DBPORT}"
  fi

  echo "${ARGS}"
}

function set_pne_member(){
  if [ "`is_db_exist`" == "0" ]; then
    pne_log "${G_DATABASE} is not exist" "error"
    exit 1
  fi

  local PASS=`create_password 8`

  local ARGS=`get_db_args`
  mysql $ARGS <<EOF
UPDATE member_config SET value = '${G_ADMIN_EMAIL}', name_value_hash = MD5(CONCAT(name, ',', value)) WHERE member_id = 1 AND name = 'pc_address';
UPDATE member_config SET value = MD5('${PASS}'), name_value_hash = MD5(CONCAT(name, ',', value)) WHERE member_id = 1 AND name = 'password';
EOF

  LINE=`mysql $ARGS -e "SELECT * FROM member_config WHERE member_id = 1 AND name_value_hash = MD5(CONCAT('pc_address', ',', '${G_ADMIN_EMAIL}'))"`
  if [ "${LINE}" == "" ]; then
    pne_log "mysql cannot udpate member_id1's mail address" "error"
# need to abort?
 fi

  LINE=`mysql $ARGS -e "SELECT * FROM member_config WHERE member_id = 1 AND name_value_hash = MD5(CONCAT('password', ',', MD5('${PASS}')))"`

  if [ "${LINE}" == "" ]; then
    pne_log "mysql cannot udpate admin's password" "error"
      # need to abort?
  fi

  echo $PASS
}

function set_install_options(){
  pne_log "setup install options"
  local ARGS=`get_db_args`

  mysql $ARGS <<EOF
INSERT INTO plugin (name, is_enabled, created_at, updated_at) values ("opTimelinePlugin", "1", NOW(), NOW()), ("opLikePlugin", "1", NOW(), NOW()), ("opSkinThemePlugin", "1", NOW(), NOW()), ("opSkinBasicPlugin", "0", NOW(), NOW()), ("opDiaryPlugin", "0", NOW(), NOW()), ("opAutoFriendPlugin", "0", NOW(), NOW()), ("opUploadFilePlugin", "0", NOW(), NOW()), ("opMessagePlugin", "0", NOW(), NOW()), ("opChatTaskPlugin", "0", NOW(), NOW());
INSERT INTO sns_config (name, value) values ("Theme_used", "united"), ("sns_name", "MySNS");
UPDATE community SET name = "管理コミュニティ" WHERE id = 1;
EOF

  case $G_INSTALL_OPTIONS in
    "business") mysql $ARGS <<EOF
UPDATE sns_config SET value = "cerulean" WHERE name = "Theme_used";
UPDATE plugin SET is_enabled = "1" where name = "opDiaryPlugin" OR name = "opAutoFriendPlugin" OR name = "opUploadFilePlugin" OR name = "opMessagePlugin" OR name = "opChatTaskPlugin";
INSERT INTO gadget (type, name, sort_order, created_at, updated_at) value ("sideBannerContents", "fMenu", 20, NOW(), NOW());
EOF
;;
    "game") mysql $ARGS <<EOF
UPDATE sns_config SET value = "superhero" WHERE name = "Theme_used";
UPDATE plugin SET is_enabled = "1" where name = "opDiaryPlugin" OR name = "opAutoFriendPlugin" OR name = "opMessagePlugin";
INSERT INTO gadget (type, name, sort_order, created_at, updated_at) value ("sideBannerContents", "fMenu", 20, NOW(), NOW());
EOF
;;
    *) pne_log "undefine mode" "error";;
  esac
}

function set_pne_admin(){
  local PASS=`create_password 8`

  local ARGS=`get_db_args`
  mysql $ARGS <<EOF
UPDATE admin_user SET password= MD5('$PASS') WHERE username = 'admin';
UPDATE admin_user SET username= '$G_ADMIN_EMAIL' WHERE username = 'admin';
EOF

  LINE=`mysql $ARGS -e "SELECT * FROM admin_user WHERE username = '$G_ADMIN_EMAIL' AND password = MD5('${PASS}')"`
  if [ "${LINE}" == "" ]; then
    pne_log "mysql cannot udpate admin's password" "error"
      # need to abort?
  fi

  mysql $ARGS <<EOF
INSERT INTO sns_config (name, value) VALUES ('admin_mail_address', '${G_ADMIN_EMAIL}' )
EOF

  LINE=`mysql $ARGS -e "SELECT * FROM sns_config WHERE name='admin_mail_address' AND value='${G_ADMIN_EMAIL}' "`
  if [ "${LINE}" == "" ]; then
    pne_log "mysql cannot insert admin's mail addresss" "error"
    #need to abort?
  fi

  echo $PASS
}

function is_db_exist(){
  local ARGS=`get_db_args`
  local line=`mysql $ARGS -e "show databases"`
  if [[ "${line}" =~ "${G_DATABASE}" ]]; then
   return 1
  fi
  return 0
}


## main
pne_log "pne install start" "info"
#is_not_root
is_correct_options "${#@}"
check_domain_list

install_pne

set_mail_conf
set_cron_conf

member_pass=$(set_pne_member)
admin_pass=$(set_pne_admin)

set_install_options

php symfony project:clear-controllers

echo "$G_HOSTNAME" >> /var/www/sites/a3.xpne.info/pma/autoinst/used_domain_list.txt
echo "$G_HOSTNAME" >> /var/www/sites/a3.xpne.info/pma/autoinst/installed_domain_list.txt

pne_log "OpenPNE installation and settings is completed" "info"
echo "${member_pass} ${admin_pass}"

#!/usr/bin/env bash

###################################
### 		VARIABLES			###
### CHANGE FOR YOUR OWN INSTALL ###
###################################

export EMU_HOME=$1
export CLIENT=$2
export TEXPRESS_VER=$3
export TEXAPI_VER=$4

export EMU_LINK=$5
export TEXPRESS_LINK=$6
export TEXAPI_LINK=$7

export TEXPRESS_LIC=$8
###
###

echo 'EMU HOME' ${EMU_HOME}

# Create emuadmin group
addgroup emuadmin
# Create emu account and add to emuadmin group
adduser --home ${EMU_HOME} --ingroup emuadmin --gecos "" emu # > /dev/null 2>&1
# echo ${thePassword} | passwd emu --stdin

####################
### Dependencies ###
####################

sudo apt-get install -y curl > /dev/null 2>&1

# Update all modules
apt-get update --fix-missing > /dev/null 2>&1
#Perl
apt-get install -y perl
apt-get install -y xinetd > /dev/null 2>&1
# Apache
#apt-get install -y apache2
#rm -rf /var/www
#ln -fs /vagrant /var/www
### Required for 64-bit ###
# apt-get install ia32-libs

############################
###   INSTALL TEXPRESS   ###
############################
chmod 755 -R ${EMU_HOME}

# do as emu
su emu <<'EOF'
cd ${EMU_HOME}

mkdir 'install_log'

mkdir -p texpress/${TEXPRESS_VER}/install
cd texpress/${TEXPRESS_VER}/install

# Download texpress
echo 'Downloading texpress...' ${TEXPRESS_LINK}
wget -q -O texpress.sh ${TEXPRESS_LINK} >> ${EMU_HOME}'/install_log/log.txt' 2>&1
echo 'Finished.'

sh texpress.sh
. ./.profile
export TEXGROUP=emuadmin

bin/texinstall ${EMU_HOME}/texpress/${TEXPRESS_VER} >> ${EMU_HOME}'/install_log/log.txt' 2>&1
cd ${EMU_HOME}/texpress/${TEXPRESS_VER}
. ./.profile
texbldperms
bin/texlicinfo

echo ${TEXPRESS_LIC} > '.license'
bin/texlicset < '.license'

\rm -fr install

cd ${EMU_HOME}/texpress
ln -s ${TEXPRESS_VER} 8.3

echo 'Texpress install complete.' >> ${EMU_HOME}'/install_log/log.txt' 2>&1

# TEXAPI INSTALL
cd ${EMU_HOME}/texpress
mkdir ${TEXAPI_VER}
wget -q -O texapi.sh ${TEXAPI_LINK} >>${EMU_HOME}'/install_log/log.txt' 2>&1
sh texapi.sh -i ~emu/texpress/${TEXAPI_VER} >> ${EMU_HOME}'/install_log/log.txt' 2>&1
\rm -f texapi
ln -s ${TEXAPI_VER} texapi
\rm -f texapi.sh

###
# EMU INSTALL
###
cd ${EMU_HOME}
mkdir -p ${CLIENT}/install
cd ${CLIENT}/install
# Download client server
echo 'Downloading client EMu server...'
wget -q -O emu-${CLIENT}.sh ${EMU_LINK} >> ${EMU_HOME}'/install_log/log.txt' 2>&1
echo 'Begining install..'
# Changed this from emu-clientname-YYYYMMDD.sh to a standard file name 
sh emu-${CLIENT}.sh >> ${EMU_HOME}'/install_log/log.txt' 2>&1
. ./.profile
bin/emuinstall ${CLIENT} >> ${EMU_HOME}'/install_log/log.txt' 2>&1
cd ${EMU_HOME}/${CLIENT}
cp .profile.parent ../.profile
cd ..

# Add a single line client clientname to the file and save it. 
# If a default client is already registered then you may leave the existing value.
echo client ${CLIENT} >> '.profile-local'

. ./.profile
client ${CLIENT}
cd etc
### OPTIONAL
# 17.	View the config.sample file.
# If you wish to alter some of these settings to suit the client then:
# 	1.	Enter cp config.sample config
# 	2.	Enter vi config
# 	3.	Edit as appropriate, then save the file.
# Be careful to set EMUSMTPSERVER to the hostname of your mail server machine.

cd ..
emubldlinks >> ${EMU_HOME}'/install_log/log.txt' 2>&1
emulutsrebuild -t -f >> ${EMU_HOME}'/install_log/log.txt' 2>&1

echo 'Cleaning up install..'
# Removal of the the temporary directory (and its contents) is recommended:
\rm -fr install

# In order to allow easier upgrades of Texpress (without having to update the etc/opts file) all 
# Texpress options are now set in the client specific .profile-local file. When installing 
# EMu 4.3 you will have to add all Texpress options required for the installation. In particular 
# the dateorder, dateformat, timeformat, latitudeformat, longitudeformat, tmppath and loadmemory 
# settings should be examined. Please see Texpress options for a list of acceptable values. 

# Enter vi .profile-local and add the Texpress options to the file. An example file is:
echo client ${CLIENT} >> '.profile-local'
TEXPRESSOPTS="${TEXPRESSOPTS} dateorder=mdy dateformat='dd MMM yyyy'"
export TEXPRESSOPTS

cd etc
# Configure iMu Server
cp imuserver.conf.sample imuserver.conf
# 	2.	Enter vi imuserver.conf
# 	3.	Edit as appropriate, then save the file.
#Be careful to set the main-port property as a minimum. The value of main-port is generally 20000 more than that used by the Windows client.
#-OR-
# 	If the IMu server is not to be used, the following steps are required:
# 	1. 	Enter cd ..
# 	2.	Enter touch loads/imu/disabled

# 3. Installation Notes (EMu Server - root)
# run as root

#3.	Add new services to the end of /etc/services
EOF

echo "emu	20000/tcp 
emutest	20002/tcp 
emutrain	20001/tcp 
${CLIENT} 	20150/tcp" >> '/etc/services'

echo ${CLIENT} stream tcp nowait root ${EMU_HOME}/${CLIENT}/bin/emurun emurun texserver -aemu -i -L -t60 >> /etc/inetd.conf
echo emu stream tcp nowait root ${EMU_HOME}/${CLIENT}/bin/emurun emurun texserver -aemu -i -L -t60 >> /etc/inetd.conf

# Stop Proc.
service xinetd stop

cd /etc/xinetd.d
echo "service ${CLIENT}
{
  flags = REUSE   
  protocol = tcp   
  socket_type = stream   
  wait = no
  user = root   
  server = ${EMU_HOME}/${CLIENT}/bin/emurun
  server_args = texserver -aemu -i -L -t60
  log_on_failure += USERID
  disable = no
}" >> ${CLIENT}

# Start Proc.
service xinetd start

echo "#
# KE EMu startup
#
${EMU_HOME}/${CLIENT}/bin/emuboot" >> /etc/init.d/rc.local

${EMU_HOME}/${CLIENT}/bin/emuboot

echo 'EMu install complete'

su emu <<'EOF'
"emuload status"
EOF
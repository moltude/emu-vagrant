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
adduser --home ${EMU_HOME} --ingroup emuadmin --gecos "" emu > /dev/null 2>&1
# echo ${thePassword} | passwd emu --stdin

####################
### Dependencies ###
####################

echo '###############################'
echo '### Installing dependencies ###'
echo '###############################'

# Update all

echo 'Update fix-missing'
# sudo ${cmd} update -y && sudo apt-get dist-upgrade -y > /dev/null 2>&1
# Update and fix missing
sudo apt-get update --fix-missing > /dev/null 2>&1

# Install CURL
echo 'Installing CURL'
sudo apt-get install -y curl > /dev/null 2>&1

# Install MAKE
# echo 'Installing Make'
# sudo apt-get install -y make > /dev/null 2>&1

# Install Perl
# echo 'Installing Perl'
# sudo apt-get install -y perl > /dev/null 2>&1

# Install XINETD
echo 'Installing Xinetd'
sudo apt-get install -y xinetd > /dev/null 2>&1

# Install CPAN
echo 'Installing CPAN'
sudo apt-get install cpanminus -y > /dev/null 2>&1

# Update outdated
echo 'Updating outdated modules'
sudo cpanm App::cpanoutdated > /dev/null 2>&1

##############################
###			EMu 		   ###
### Required for 64-bit OS ###
##############################
echo 'Installing 32-bit ia32-libs'
sudo apt-get install -y ia32-libs > /dev/null 2>&1
# sudo apt-get install -y ia32-libs-multiarch
sudo apt-get install -y libpam-modules:i386 > /dev/null 2>&1
sudo apt-get install -y libpam0g:i386  > /dev/null 2>&1

# http://portal.archiware.com/support/index.php?/Knowledgebase/Article/View/108/16/errors-on-64-bit-ubuntu-linux
 

############################
###   INSTALL TEXPRESS   ###
############################
sudo chmod 755 -R ${EMU_HOME}

# Do as emu user
su emu <<'EOF'
cd ${EMU_HOME}

mkdir 'log'

mkdir -p texpress/${TEXPRESS_VER}/install
cd texpress/${TEXPRESS_VER}/install

# Download texpress
echo 'Downloading texpress...' ${TEXPRESS_LINK}
wget -q -O texpress.sh ${TEXPRESS_LINK} >> ${EMU_HOME}'/log/log.txt' 2>&1
echo 'Finished.'

sh texpress.sh >> ${EMU_HOME}'/log/log.txt' 2>&1
source .profile
export TEXGROUP=emuadmin

echo '##################################'
echo '###### INSTALLING TEXPRESS #######'
echo '##################################'

bin/texinstall ${EMU_HOME}/texpress/${TEXPRESS_VER} >> ${EMU_HOME}'/log/log.txt' 2>&1
cd ${EMU_HOME}/texpress/${TEXPRESS_VER}
source .profile

bin/texbldperms
bin/texlicinfo

echo 'export TEXHOME=${EMU_HOME}/texpress/${TEXPRESS_VER}/' >> ${EMU_HOME}'/.profile'
source .profile

echo ${TEXPRESS_LIC} > '.license'
${EMU_HOME}/texpress/${TEXPRESS_VER}/bin/texlicset < '.license'

\rm -fr install

cd ${EMU_HOME}/texpress
ln -s ${TEXPRESS_VER} 8.3

echo 'Texpress install complete.' >> ${EMU_HOME}'/log/log.txt' 2>&1

EOF


# Red Hat 6, CentOS 6 or Fedor Core 8 Linux
#
#  /etc/pam.d/texpress
# Do as root

echo 'Installing Texpress PAM entry to /etc/pam.d/texpress'

echo "
auth    required        pam_env.so
@include common-auth
@include common-account
@include common-password
@include common-session" >> /etc/pam.d/texpress


su emu <<'EOF'
echo '##################################'
echo '####### INSTALLING TEXAPI  #######'
echo '##################################'

cd ${EMU_HOME}/texpress
mkdir ${TEXAPI_VER}
wget -q -O texapi.sh ${TEXAPI_LINK} >> ${EMU_HOME}'/log/log.txt' 2>&1
sh texapi.sh -i ${EMU_HOME}/texpress/${TEXAPI_VER} >> ${EMU_HOME}'/log/log.txt' 2>&1

\rm -f texapi
ln -s ${TEXAPI_VER} texapi
\rm -f texapi.sh



echo '#############################'
echo '### INSTALLING EMU SERVER ###'
echo '#############################'

cd ${EMU_HOME}
mkdir -p ${CLIENT}/install
cd ${CLIENT}/install

# Download client server
echo 'Downloading client EMu server...'
wget -q -O emu-${CLIENT}.sh ${EMU_LINK} >> ${EMU_HOME}'/log/log.txt' 2>&1

# Changed this from emu-clientname-YYYYMMDD.sh to a standard file name 
sh emu-${CLIENT}.sh >> ${EMU_HOME}'/log/log.txt' 2>&1

source .profile

bin/emuinstall ${CLIENT} # >> ${EMU_HOME}'/log/log.txt' 2>&1
cd ${EMU_HOME}/${CLIENT}
cp .profile.parent  ../.profile

echo "export PATH=$PATH:${EMU_HOME}/${CLIENT}/bin:${EMU_HOME}/texpress/8.3/bin:" >> '.profile'
source .profile

cd ..

##
# TODO :: Why do I get an 'unknown command' error when creating this file? 
### 
echo "client ${CLIENT}" >> '.profile-local'
source .profile-local

# reload the profiles 
source .profile

client ${CLIENT}

cd etc

###############################
###### 		OPTIONAL	#######
###############################
# 
# 17.	View the config.sample file.
# If you wish to alter some of these settings to suit the client then:
# 	1.	Enter cp config.sample config
# 	2.	Enter vi config
# 	3.	Edit as appropriate, then save the file.
# Be careful to set EMUSMTPSERVER to the hostname of your mail server machine.
# cd ..
###############################

emubldlinks >> ${EMU_HOME}'/log/log.txt' 2>&1
emulutsrebuild -t -f >> ${EMU_HOME}'/log/log.txt' 2>&1

echo 'Cleaning up install..'
# Removal of the the temporary directory (and its contents) is recommended:
\rm -fr install

echo "TEXPRESSOPTS=${TEXPRESSOPTS} dateorder=mdy dateformat='dd MMM yyyy'
export TEXPRESSOPTS" >> '.profile-local'
source .profile-local


###############################
###### 		OPTIONAL	#######
###############################
# cd etc
# Configure iMu Server
cp imuserver.conf.sample imuserver.conf
# 	2.	Enter vi imuserver.conf
# 	3.	Edit as appropriate, then save the file.
#Be careful to set the main-port property as a minimum. The value of main-port is generally 20000 more than that used by the Windows client.
#-OR-
# 	If the IMu server is not to be used, the following steps are required:
# 	1. 	Enter cd ..
# 	2.	Enter touch loads/imu/disabled

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

sudo ${EMU_HOME}/${CLIENT}/bin/emuboot

echo 'EMu install complete'

su -l emu <<'EOF'
source /home/emu/.profile
emuload status
EOF

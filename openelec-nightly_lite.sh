#!/usr/bin/env bash
set -e


# "OpenELEC_DEV" ; An automated development build updater script for OpenELEC nightly builds
#
# Copyright (c) February 2012, Eric Andrew Bixler
# with some alterations made by HuwSy
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#	* Redistributions of source code must retain the above copyright
#	  notice, this list of conditions and the following disclaimer.
#	* Redistributions in binary form must reproduce the above copyright
#	  notice, this list of conditions and the following disclaimer in the
#	  documentation and/or other materials provided with the distribution.
#	* Neither the name of the <organization> nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.


# THIS SOFTWARE IS PROVIDED BY Eric Andrew Bixler ''AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Eric Andrew Bixler BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


###### we've already been updated; need to remove update indicator from out last script update run

if [ -f /tmp/update_in_progress ] ;
then
	rm -f /tmp/update_in_progress
fi


###### temporarily disable script updates ?

Allow_Update="YES"


###### script version

VERSION="40"


###### default locations

dkernel="KERNEL"
dsystem="SYSTEM"
dkmd5="KERNEL.md5"
dsmd5="SYSTEM.md5"
asystem=$dsystem

arch=$(cat /etc/arch)
mode="http://openelec.xbmcnightlybuilds.com/"$(echo $arch | sed -e 's/\..*//g')


###### set the temporary file location based on what device we are using...(the rPi does not have enough RAM to download the image to /dev/shm

echo "Device Detected: `cat /etc/arch | sed 's/\./ /g' | awk '{print $1}'`"
echo

if [ "$arch" = "RPi.arm" ] ;
then
	temploc="/storage/downloads/xbmc-update"
	akernel="kernel.img"
	# disabled as its not maintained
	# mode="http://openelec.thestateofme.com/dev_builds"
else
	temploc="/dev/shm/xbmc-update"
	akernel=$dkernel
	# disabled for this script but its still compatible
	# mode="http://sources.openelec.tv/tmp/image"
fi


###### going to check for avaliable RAM, and if there isnt more then 200MB free; just use the harddisk; this will override the variable set just above

ram_mb=$((`cat /proc/meminfo | sed -n 2p | awk '{print $2}'`/1024))
if [ "$ram_mb" -lt "200" ] ;
then
	temploc="/storage/downloads/xbmc-update"
	unset ram_mb
fi

###### removes temporary files that have been created if the user prematurly aborts the update process

trap ctrl_c 2
ctrl_c ()
{
echo -ne "\n\n"
echo "User aborted process."
echo -ne "SIGINT Interrupt caught"
echo -ne "\nTemporary files removed\n"
if [ -d $temploc ] ;
then
	rm -rf $temploc
fi
unsetv
exit 1
}


###### for cleanup purposes, we're removing some enviroment variables we've set, after the script is run or aborted

unsetv ()
{
unset kern_return
unset currentsys
unset update_yes
unset sys_return
unset SYS_KERN
unset PRESENT
unset VERSION
unset kernmd5
unset kernrom
unset temploc
unset akernel
unset asystem
unset dkernel
unset dsystem
unset sysrom
unset FOLDER
unset branch
unset sysmd5
unset rsvers
unset status
unset ALLOW
unset dkmd5
unset dsmd5
unset PAST
unset mode
unset port
unset pass
unset user
unset arch
unset reb
unset alt
unset pid
unset yn
unset ar
}


###### some visual feedback for long operations; especially useful on the RPi

spinner() {
proc=$1
while [ -d /proc/$proc ];do
echo -ne '/' ; sleep 0.05
echo -ne "\033[0K\r"
echo -ne '-' ; sleep 0.05
echo -ne "\033[0K\r"
echo -ne '\' ; sleep 0.05
echo -ne "\033[0K\r"
echo -ne '|' ; sleep 0.05
echo -ne "\033[0K\r"
done
return 0
}


###### making sure github is alive and ready to update the script if nessessary.

s_update ()
{
echo -ne "Please Wait...\033[0K\r"
sleep 2
echo -ne "\033[0K\r"
echo -ne "Checking Script Update Server State...\033[0K\r"
ping -qc 3 raw.github.com > /dev/null &
outcome="$?"
pid=$!
spinner $pid
unset pid
echo -ne "\033[0K\r"
if [ "$outcome" = "0" ] ;
then
	echo -ne "Update Server Active.\033[0K\r"
	sleep 2
	echo -ne "\033[0K\r"
	###### check if a script update is in progress
	if [ ! -f /tmp/update_in_progress ] ;
	then
		###### update_in_progress does not exist :: first run
		###### checking script version; auto updating and re-running new version
		mkdir -p $temploc
		curl --silent https://raw.github.com/wavrunrx/OpenELEC_Dev/master/openelec-nightly_latest.sh > $temploc/tempscript
		Allow=$(grep "Allow_Update=" $temploc/tempscript | grep -v grep | sed 's/=/ /g' | awk '{print $2}' | awk '{gsub(/[[:punct:]]/,"")}1')
		rsvers=$(grep "VERSION=" $temploc/tempscript | grep -v grep | sed 's/[^0-9]*//g')
		while true; do
		if [ "$rsvers" -gt "$VERSION" ] ;
		then
			if [ "$Allow" = "NO" ] ;
			then
				echo "| Script Updates are temporarily disabled |"
				echo "| Continuing..."
				echo
				break
			fi
			echo
			echo "*---| Script Update Available."
			echo "*---| Current Version: $VERSION"
			echo "*---| New Version: $rsvers"
			echo
			echo "Commit/Change Log:"
			echo "------------------"
			echo "https://github.com/wavrunrx/OpenELEC_Dev/commits/master"
			echo
			echo
			while true; do
			echo "Would you like to update the script now (y/n) ?"
			read -n1 -p "==| " supdate
			supdate=$supdate
			if [[ $supdate != "Y" ]] && [[ $supdate != "y" ]] && [[ $supdate != "N" ]] && [[ $supdate != "n" ]] ;
			then
				echo
				echo
				echo "Unrecognized Input."
				sleep 1
				echo "Please answer (y/n)"
				echo
				continue
			elif [[ $supdate = "Y" || $supdate = "y" ]] ;
			then
				echo
				echo
				echo
				echo "*---| Updating OpenELEC_DEV:"
				echo -ne "      Please Wait...\033[0K\r"
				sleep 1
				curl --silent -fksSL -A "`curl -V | head -1 | awk '{print $1, $2, $3}'`" http://bit.ly/TOf3qf > `dirname $0`/openelec-nightly_$rsvers.sh &
				pid=$!
				spinner $pid
				unset pid
				echo -ne "\033[0K\r"
				echo "Done !"
				echo
				echo
				sleep 1
				echo "BEGIN: OpenELEC_DEV v$rsvers Now"
				echo "---------------------------"
				echo
				echo
				echo
				###### indicate update in progress to next script instance
				touch /tmp/update_in_progress
				###### indicate no update check nessessary to next script instance since we've just finished a check
				touch /tmp/no_display
				###### remove update indication flag
			 	rm -f /tmp/update_in_progress
				###### swapping old script with new
				rm -f `dirname $0`/openelec-nightly_latest.sh
				mv `dirname $0`/openelec-nightly_$rsvers.sh `dirname $0`/openelec-nightly_latest.sh
				chmod 755 `dirname $0`/openelec-nightly_latest.sh
				###### run a new version of update script
				sh `dirname $0`/openelec-nightly_latest.sh
				###### exit old script
				exit
			elif [[ $supdate = "N" || $supdate = "n" ]] ;
			then
				echo
				echo
				echo
				break
			fi
			done
		else
			echo -ne "Script Update Not Avaliable.\033[0K\r"
			sleep 2
			echo -ne "\033[0K\r"
			echo -ne "Continuing...\033[0K\r"
			sleep 2
			echo -ne "\033[0K\r"
			break
		fi
		done
	fi
else
	echo
	echo "* Script Update Server Not Responding."
	echo "* Try again later."
	echo "  -------------------------------"
	echo -ne "Continuing...\033[0K\r"
	sleep 2
	echo -ne "\033[0K\r"
	echo
fi
}


###### if 'no_display' exists, we are going to skip the update check; otherwise, we check

if [ ! -f /tmp/no_display ] ;
then
	s_update
fi


###### remove no update check nessessary indicator so next time we run the script we will again check for updates

rm -f /tmp/no_display


###### create the .update directory for OpenELEC

mkdir -p /storage/.update


###### checking for a previous run :: if SYSTEM & KERNEL files are still in ~/.update then we havent rebooted since we last ran.
###### this check prevents us from redownloading the update package.

while true; do
	SYS_KERN=$(ls /storage/.update/* 2> /dev/null | wc -l)
	if [ "$SYS_KERN" = "4" ] ;
	then
		echo
		echo
		echo "KERNEL & SYSTEM are already in place."
		echo "You must reboot to complete the update."
		echo "Would you like to reboot now (y/n) ?"
		read -n1 -p "==| " reb
	if [[ $reb != "Y" ]] && [[ $reb != "y" ]] && [[ $reb != "N" ]] && [[ $reb != "n" ]] ;
	then
		echo
		echo
		echo "Unrecognized Input."
		sleep 1
		echo "Please answer (y/n)"
		continue
	elif [[ $reb = "Y" || $reb = "y" ]] ;
	then
		echo
		echo
		echo
		echo "Rebooting..."
		rm -rf $temploc
		unsetv
		sync
		sleep 2
		/sbin/reboot
	elif [[ $reb = "N" || $reb = "n" ]] ;
	then
		echo
		echo
		echo "Please reboot to complete the update."
		sleep 1
		echo "Exiting."
		rm -rf $temploc
		unsetv
		exit 0
		fi
	fi
	break
done


###### delete the temporary working directory; create if doesnt exist

if [ -d "$temploc" ] ;
then
	rm -rf $temploc
	mkdir -p $temploc
else
	mkdir -p $temploc
fi


###### if there are no builds avaliable on the server for your specific architecture, we are going to notify you, and gracefully exit
###### also captures remote filename & extension to be used at later times

arch=$(cat /etc/arch)
ar="\"[^\"]*${arch//\./\.}[^\"]*\.tar*\""
curl --silent $mode/ | grep -o $ar | sed -e 's/"//g' | sed -e 's/\/ATV\///' | sed -e 's/\/Fusion\///' | sed -e 's/\/Generic\///' | sed -e 's/\/Intel\///' | sed -e 's/\/ION\///' | sed -e 's/\/RPi\///' | sed -e 's/\/Virtual\///' | tail -n 1 > $temploc/temp
if [[ -z `cat $temploc/temp` ]] ;
then
	echo "There are either no available builds for your architecture at this time, or"
	echo "the only build avaliable is the same revision you are already on."
	echo "Please check again later."
	echo
	echo "Exiting Now."
	rm -rf $temploc
	unsetv
	exit 1
fi


###### remove all but the newest build from our list

if [ $(wc -l $temploc/temp | cut -c -1) -gt "1" ] ;
then
	cat $temploc/temp | tail -n 1 > $temploc/temp2
else
	mv $temploc/temp $temploc/temp2
fi

if [ -f $temploc/temp ] ;
then
	rm $temploc/temp
fi


###### i386, or x86_64 ?
instruction_set=$(cat /etc/arch | sed 's/\./ /g' | awk '{print $2}')

## filename
FOLDER=$(cat $temploc/temp2)

## capture local build revision
PAST=$(cat /etc/version | awk '{gsub(/[[:punct:]]/," ")}1' | awk '{print $3}' | tr -d 'r')

## capture remote build revision (allows infinite revision growth)
PRESENT=$(cat $temploc/temp2 | awk '{gsub(/[[:punct:]]/," ")}1' | awk '{print $6}' | tr -d 'r')


###### set $PRESENT properly for 64-bit machines

if [ "$instruction_set" = "x86_64" ] ;
then
	PRESENT=$(cat $temploc/temp2 | awk '{gsub(/[[:punct:]]/," ")}1' | awk '{print $7}' | tr -d 'r')
fi


###### checking to make sure we are actually running an official development build. if we dont check this; the comparison routine will freak out if our local
###### build is larger then the largest (newest) build on the official openelec snapshot server.

if [ "$PRESENT" -lt "$PAST" ] ;
then
	echo
	echo "You are currently using an unofficial development build of OpenELEC."
	echo "This isn't supported, and will yield unexpected results if we continue."
	echo "Your build is a higher revision then the highest available on the official"
	echo "snapshot server as seen here: "$mode
	echo "In order to use this update script, you *MUST* be using an official"
	echo "build, that was obtained from the aforementioned snapshot server."
	echo
	echo "Local:  $PAST"
	echo "Remote: $PRESENT"
	echo
	sleep 2
	echo "Exiting Now."
	echo
	rm -rf $temploc
	unsetv
	exit 1
fi


###### this is only comes into play if the option -q is passed. if so, we supress output if an update isnt available. if one is, we dont care, and want to exit (this will be used for the addon gui sometime in the future)

if [ "$update_yes" = "1" ] ;
then
	exit 0
fi


###### variables used for GUI notifications

## xbmc webserver port
port=$(cat /storage/.xbmc/userdata/guisettings.xml | grep "<webserverport>" | sed 's/[^0-9]*//g')

## xbmc webserver password
pass=$(cat /storage/.xbmc/userdata/guisettings.xml | grep "<webserverpassword>" | grep -Eio "[a-z]+" | sed -n 2p)

## xbmc webserver username
user=$(cat /storage/.xbmc/userdata/guisettings.xml | grep "<webserverusername>" | grep -Eio "[a-z]+" | sed -n 2p)


###### compare local and remote revisions; decide if we have updates ready to donwload

if [ "$PRESENT" -gt "$PAST" ] ;
then
	echo
	echo "### WARNING:"
	echo "### UPDATING TO OR FROM DEVELOPMENT BUILDS MAY HAVE POTENTIALLY UNPREDICTABLE"
	echo "### EFFECTS ON THE STABILITY AND OVERALL USABILITY OF YOUR SYSTEM. SINCE NEW"
	echo "### CODE IS LARGELY UNTESTED, DO NOT EXPECT SUPPORT ON ANY ISSUES YOU MAY"
	echo "### ENCOUNTER. IF SUPPORT WERE TO BE OFFERED, IT WILL BE LIMITED TO"
	echo "### DEVELOPMENT LEVEL DEBUGGING."
	echo
	echo
	echo -ne "Please Wait...\033[0K\r"
	sleep 2
	echo -ne "\033[0K\r"
	echo ">>>| OpenELEC"
	echo "Updates Are Available."
	echo "Local:   $PAST          Compiled: `cat /etc/version | cut -f 2-2 -d'-' | sed 's/......$//;s/./& /4' | sed 's/./& /7' | awk '{ print "[ "$2"/"$3"/"$1" ]" }'`"
	echo "Remote:  $PRESENT          Compiled: `echo $FOLDER | cut -f 4-4 -d'-' | sed 's/......$//;s/./& /4' | sed 's/./& /7' | awk '{ print "[ "$2"/"$3"/"$1" ]" }'`"
	echo
	echo "`cat /etc/arch | sed 's/\./ /g' | awk '{print $1}'` Build Source:"
	echo $mode
	#curl -v -H "Content-type: application/json" -u $user:$pass -X POST -d '{"id":1,"jsonrpc":"2.0","method":"GUI.ShowNotification","params":{"title":"OpenELEC_Dev","message":"Update Found ! Remote Build: $PRESENT","displaytime":8000}}' http://localhost:$port/jsonrpc
	echo
	## The remote build is newer then our local build. Asking for input.
	echo "Would you like to update (y/n) ?"
	read -n1 -p "==| " yn
	if [[ $yn != "Y" ]] && [[ $yn != "y" ]] && [[ $yn != "N" ]] && [[ $yn != "n" ]] ;
	then
		echo
		echo
		echo "Unrecognized Input."
		sleep 2
		echo "Please answer (y/n)"
		echo "Exiting."
		echo
		rm -rf $temploc
		unsetv
		exit 1
	elif [[ $yn = "Y" || $yn = "y" ]] ;
	then
		sleep .5
		echo
		echo
		echo "Downloading Image: $mode/`cat $temploc/temp2` to $temploc"
		wget $mode/`cat $temploc/temp2` -P "$temploc"
		echo "Done!"
		extract="$temploc/$FOLDER"
		sleep 1
	elif [[ $yn = "N" || $yn = "n" ]] ;
	then
		echo
		echo
		echo "User aborted process."
		sleep 2
		echo "Exiting."
		echo
		rm -rf $temploc
		unsetv
		exit 0
	fi
else
	## remote build is not newer then what we've got already. Exit.
	echo -ne "\033[0K\r"
	echo
	echo ">>>| OpenELEC"
	echo "No Updates Available."
	echo "Local:   $PAST          Compiled: `cat /etc/version | cut -f 2-2 -d'-' | sed 's/......$//;s/./& /4' | sed 's/./& /7' | awk '{ print "[ "$2"/"$3"/"$1" ]" }'`"
	echo "Remote:  $PRESENT          Compiled: `echo $FOLDER | cut -f 4-4 -d'-' | sed 's/......$//;s/./& /4' | sed 's/./& /7' | awk '{ print "[ "$2"/"$3"/"$1" ]" }'`"
	echo
	echo "You are on the latest build for your platform [`cat /etc/arch`]"
	echo "Check again later."
	echo
	rm -rf $temploc
	unsetv
	exit 0
fi


###### extract SYSTEM & KERNEL images to the proper location for update

echo
echo "Extracting Files: from $extract to $temploc"
if [[ $extract == *bz2 ]]
then
	tar -xjf $extract -C $temploc &
else
	tar -xf $extract -C $temploc &
fi
pid=$!
spinner $pid
echo "Done!"
unset pid
sleep 2


###### Move KERNEL & SYSTEM  and respective md5's to /storage/.update/
echo
echo "Moving Images To: /storage/.update"
echo -ne "Please Wait...\033[0K\r"
mv $temploc/OpenELEC-*/target/* /storage/.update &
pid=$!
spinner $pid
echo -ne "\033[0K\r"
echo "Done!"
unset pid
sleep 2


###### Compare md5-sums

sysmd5=$(cat /storage/.update/$dsmd5 | awk '{print $1}')
kernmd5=$(cat /storage/.update/$dkmd5 | awk '{print $1}')
kernrom=$(md5sum /storage/.update/$dkernel | awk '{print $1}')
sysrom=$(md5sum /storage/.update/$dsystem | awk '{print $1}')

echo "Data Integrity Check:"
if [ "$sysmd5" = "$sysrom" ] ;
then
	echo
	echo "md5 ==> SYSTEM: OK!"
	sys_return=0
	sleep 2
else
	sys_return=1
	echo "---   WARNING   ---"
	echo "SYSTEM md5 MISMATCH!"
	echo "--------------------"
	echo "There is an integrity problem with the SYSTEM package"
	echo "Notify one of the developers in the Forums or IRC that"
	echo "the SYSTEM image is corrupt"
	echo
	echo "IRC Webchat:"
	echo "http://webchat.freenode.net/?channels=openelec"
	sleep 3
	rm -f /storage/.update/$dsystem
	rm -f /storage/.update/$dsmd5
	rm -rf $temploc
	sync
fi

if [ "$kernmd5" = "$kernrom" ] ;
then
	echo "md5 ==> KERNEL: OK!"
	kern_return=0
else
	kern_return=1
	echo "---   WARNING   ---"
	echo "KERNEL md5 MISMATCH!"
	echo "--------------------"
	echo "There is an integrity problem with the KERNEL package"
	echo "Notify one of the developers in the Forums or IRC that"
	echo "the KERNEL image is corrupt"
	echo
	echo "IRC Webchat:"
	echo "http://webchat.freenode.net/?channels=openelec"
	sleep 3
	rm -f /storage/.update/$dkernel
	rm -f /storage/.update/$dkmd5
	rm -rf $temploc
	sync
fi


###### the system rom is evaluated first.
###### if an error is found, the process is terminated and we wouldnt know if the kernel image was broken as well.
######
###### here we know that if the sum of $kern_return, and $sys_return is over "1", that one or both of the images are broken, and we've already been
###### notified which one it was above. Exit.

return=$(($kern_return+$sys_return))
if [[ "$return" = "2" ]] ;
then
	echo "md5 Mismatch Detected."
	echo "Update Terminated."
	rm -rf $temploc
	unsetv
	exit 1
fi

sleep 1
echo "File Integrity Check: PASSED!"
echo
echo -ne "Continuing...\033[0K\r"
sleep 2
echo -ne "\033[0K\r"
echo


###### remove old backup builds

rm -rf /storage/downloads/OpenELEC_r*


###### make sure 'downloads' exists; doesnt get created untill the "Downloads" smb share is accessed for the first time.

mkdir -p /storage/downloads


###### create a backup of our current, and new build for easy access if needed for a emergency rollback

echo "Creating a backup of your PREVIOUS [ SYSTEM & KERNEL ] images."
echo -ne "Please Wait...\033[0K\r"
mkdir /storage/downloads/OpenELEC_r$PAST
cp /flash/$akernel /storage/downloads/OpenELEC_r$PAST/$dkernel
cp /flash/$asystem /storage/downloads/OpenELEC_r$PAST/$dsystem
chmod +x /storage/downloads/OpenELEC_r$PAST/$dkernel
chmod +x /storage/downloads/OpenELEC_r$PAST/$dsystem
md5sum /storage/downloads/OpenELEC_r$PAST/$dkernel > /storage/downloads/OpenELEC_r$PAST/$dkmd5 &
pid=$!
spinner $pid
unset pid
md5sum /storage/downloads/OpenELEC_r$PAST/$dsystem > /storage/downloads/OpenELEC_r$PAST/$dsmd5 &
pid=$!
spinner $pid
unset pid
echo -ne "\033[0K\r"
echo
echo "     Important Notice"
echo "--------------------------"
echo "     In the need of an emergency rollback:"
echo "-->  A backup copy of your *PREVIOUS* SYSTEM & KERNEL images [ revision $PAST ]"
echo "     have been created here:  /storage/downloads/OpenELEC_r$PAST"
echo
echo
echo "Creating a backup of your NEW [ SYSTEM & KERNEL ] images."
echo -ne "Please Wait...\033[0K\r"
mkdir -p /storage/downloads/OpenELEC_r$PRESENT
sleep 1
cp /storage/.update/$dkernel /storage/.update/$dsystem /storage/.update/$dkmd5 /storage/.update/$dsmd5 /storage/downloads/OpenELEC_r$PRESENT &
pid=$!
spinner $pid
unset pid
echo -ne "\033[0K\r"
echo
echo "     Important Notice"
echo "--------------------------"
echo "     In the need of an emergency rollback:"
echo "-->  A backup copy of your *NEW* SYSTEM & KERNEL images [ revision $PRESENT ]"
echo "     have been created here:  /storage/downloads/OpenELEC_r$PRESENT"
echo
sleep 5


###### ask if we want to reboot now

echo
echo
echo "Update Preperation Complete !"
sleep 2
while true; do
echo
echo "You must reboot to finish the update."
echo "Would you like to reboot now (y/n) ?"
read -n1 -p "==| " reb
echo
if [[ "$reb" != "Y" ]] && [[ "$reb" != "y" ]] && [[ "$reb" != "N" ]] && [[ "$reb" != "n" ]] ;
then
	echo
	echo "Unrecognized Input."
	echo "Please answer (y/n)"
	echo
	continue
elif [[ "$reb" = "Y" || "$reb" = "y" ]] ;
then
	sleep 1
	echo
	echo "Rebooting..."
	rm -rf $temploc
	sync
	/sbin/reboot
elif [[ "$reb" = "N" || "$reb" = "n" ]] ;
then
	sleep 1
	echo
	echo "User aborted process."
	echo "Please reboot to complete the update."
	echo "Exiting."
	rm -rf $temploc
	unsetv
	exit 1
fi
done


## everything went well: we're done !

exit 0

#!/bin/bash

Help()
{
   # Display Help
   echo "Add description of the script functions here."
   echo
   echo "Syntax: scriptTemplate [-g|h|v|V]"
   echo "options:"
   echo "g     Print the GPL license notification."
   echo "h     Print this Help."
   echo "v     Verbose mode."
   echo "V     Print software version and exit."
   echo
}

SHARED="/datasets/teams/hackathon-testing"
#SHARED="/home"

# note these uid/gids are only for Containers for Bob Robey.
# you MUST use other number for other Containers !

HACKATHONBASEUSER=12050
HACKATHONBASEGROUP=12000

DRYRUN=1

source userlist.sh

i=0

HACKATHONLASTUSER=$((HACKATHONBASEUSER-1))
HACKATHONLASTGROUP=$((HACKATHONBASEGROUP-1))

# First see what user ids and group ids are used by files in 
# the Home directory tree and set the max to 
sudo find ${SHARED} -type f -print0 | while read -r -d '' file; do
   uid=`sudo stat -c %u $file`
   if [[ ! -z "$uid" ]]; then
      if (( $uid > ${HACKATHONLASTUSER} )); then
         HACKATHONLASTUSER=$uid
      fi
   fi
   gid=`sudo stat -c %g $file`
   if [[ ! -z "$gid" ]]; then
      if (( $gid > ${HACKATHONLASTGROUP} )); then
         HACKATHONLASTGROUP=$gid
      fi
   fi
   #echo "User id is $uuid Group id is $gid for file $file"
done
while IFS='' read -r line; do
   gid=`echo $line | cut -d':' -f 3`
   echo "Group id is $ggid"
   if [[ ! -z "$gid" ]]; then
      if (( $gid > 15000 )); then
	 continue
      fi
      if (( $gid > ${HACKATHONLASTGROUP} )); then
         HACKATHONLASTGROUP=$gid
      fi
   fi
done < /etc/group
while IFS='' read -r line; do
   uid=`echo $line | cut -d':' -f 3`
   gid=`echo $line | cut -d':' -f 4`
   echo "User id is $uuid Group id is $gid"
   if [[ ! -z "$gid" ]]; then
      if (( $gid > ${HACKATHONLASTGROUP} )); then
         if (( $gid < 15000 )); then
            HACKATHONLASTGROUP=$gid
	 fi
      fi
   fi
   if [[ ! -z "$uid" ]]; then
      if (( $uid > ${HACKATHONLASTUSER} )); then
         if (( $uid < 15000 )); then
            HACKATHONLASTUSER=$uid
         fi
      fi
   fi
done < /etc/passwd

HACKATHONBASEUSER=$((HACKATHONLASTUSER+1))
HACKATHONBASEGROUP=$((HACKATHONLASTGROUP+1))

echo ""
echo "Base User id is $HACKATHONBASEUSER Group id is $HACKATHONBASEGROUP"
echo ""

#uncomment
#sudo groupadd -f -g ${HACKATHONGROUP} hackathon
#sudo usermod -a -G  ${HACKATHONGROUP} teacher

# uncomment for real run

if [ ! -f /users/default/aac1.termsOfUse.txt ]; then
   echo "sudo cp ${HOME}/aac1.termsOfUse.txt /users/default"
   echo "sudo chmod 666 /users/default/aac1.termsOfUse.txt"
   if [ "${DRYRUN}" != 1 ]; then
      sudo cp ${HOME}/aac1.termsOfUse.txt /users/default
      sudo chmod 666 /users/default/aac1.termsOfUse.txt
   fi
fi
if [ ! -f /users/default/bash_profile ]; then
   echo "sudo cp ${HOME}/bash_profile /users/default"
   echo "sudo chmod 666 /users/default/bash_profile"
   if [ "${DRYRUN}" != 1 ]; then
      sudo cp ${HOME}/bash_profile /users/default
      sudo chmod 666 /users/default/bash_profile
   fi
fi

for u  in "${users[@]}"
do
   IFS=",", read -r -a arr <<< "${u}"

   ((i=i+1))
   first="${arr[0]}"
   last="${arr[1]}"
   user_name="${arr[2]}"
   group_name="${arr[3]}"
   sshkey="${arr[4]}"
   pw="${arr[5]}"

   echo
   echo "======================================"
   echo "first : ${first}"
   echo "last : ${last}"
   echo "username : ${user_name}"
   echo "groupname : ${group_name}"
   echo "key : ${sshkey}"
   echo "pw : ${pw}"
   echo

   # Check for blank entries
   if [ -z ${user_name} ]; then
      echo "Skipping -- username ${user_name} is blank"
      continue;
   fi

   if id "${user_name}" &>/dev/null; then
      uid=`getent passwd $user_name | cut -d: -f3`
      gid=`getent passwd $user_name | cut -d: -f4`
      USERHOMEDIR=`getent passwd $user_name | cut -d: -f6`
      echo "User $user_name already exists as UID $uid, GID $gid and home directory $USERHOMEDIR in the /etc/passwd file"

      #echo "Group id is $gid group name is $group_name"
      GROUP_NAME_EXIST=`getent group $group_name | cut -d: -f3 | wc -l`
      #echo "Group exist is ${GROUP_EXIST}"
      if [[ "${GROUP_NAME_EXIST}" != "1" ]]; then
         GROUP_ID_EXIST=`getent group $gid | cut -d: -f3 | wc -l`
	 if [[ "${GROUP_ID_EXIST}" != "1" ]]; then
            # create the group using the gid listed in the /etc/passwd file
	    echo "group $group_name is missing from /etc/group -- creating it"
            echo "  sudo groupadd -f -g ${gid} $group_name"
            if [ "${DRYRUN}" != 1 ]; then
               sudo groupadd -f -g ${gid} $group_name
	    fi
	 else
	    echo "Adding user to group $group_name and making it the primary group for the user"
            echo "  sudo usermod -a -G ${group_name}"
            echo "  sudo usermod -g ${group_name}"
            if [ "${DRYRUN}" != 1 ]; then
               sudo usermod -a -G ${group_name}
               sudo usermod -g ${group_name}
	    fi
	 fi
      fi
      # Need to add a group for the home directory if it doesn't match the user's group id
      gid_homedir=`sudo stat -c %g $USERHOMEDIR`
      if id -g "$user_name" | grep -qw "$gid_homedir"; then
         GROUP_ID_EXIST=`getent group $gid_homedir | cut -d: -f3 | wc -l`
	 #echo "GROUP_ID_EXIST is $GROUP_ID_EXIST"
	 if [[ "${GROUP_ID_EXIST}" != "1" ]]; then
            GROUP_NAME_HOMEDIR=group${group_homedir}
	    echo "Adding missing group for home directory ${GROUP_NAME_HOMEDIR}"
            echo "  sudo groupadd -f -g $group_homedir ${GROUP_NAME_HOMEDIR}"
            if [ "${DRYRUN}" != 1 ]; then
               sudo groupadd -f -g $group_homedir ${GROUP_NAME_HOMEDIR}
	    fi
	 else
            GROUP_NAME_HOMEDIR=`getent group $gid_homedir | cut -d: -f1`
	 fi
	 echo "Adding group of home directory ${GROUP_NAME_HOMEDIR} to user"
         echo "  sudo usermod -a -G ${GROUP_NAME_HOMEDIR}"
         if [ "${DRYRUN}" != 1 ]; then
            sudo usermod -a -G ${GROUP_NAME_HOMEDIR}
	 fi
      fi
   else 
      # Check if home directory exists and we need to just add the user entry
      USERHOMEDIR=`sudo find $SHARED -maxdepth 2 -name $user_name -print`
      if [[ "$USERHOMEDIR" != "" ]]; then
         uid=`sudo stat -c %u $USERHOMEDIR`
         gid=`sudo stat -c %g $USERHOMEDIR`
         GROUP_EXIST=`getent group $group_name | cut -d: -f4 | wc -l`
         #echo "Group exist is ${GROUP_EXIST}"
         if [[ "${GROUP_EXIST}" != "1" ]]; then
            # should add a check that the subdirectory matches the group name?
	    echo "home directory exists, but group for it does not. Adding group"
            echo "  sudo groupadd -f -g ${gid} $group_name"
            if [ "${DRYRUN}" != 1 ]; then
               sudo groupadd -f -g ${gid} $group_name
	    fi
         fi
	 echo "home directory exists, but user does not. Adding user"
         echo "  sudo useradd --shell /bin/bash --home ${USERHOMEDIR} --uid $uid --gid ${gid} ${user_name}"
         if [ "${DRYRUN}" != 1 ]; then
            sudo useradd --shell /bin/bash --home ${USERHOMEDIR} --uid $uid --gid ${gid} ${user_name}
	 fi

	 # Need to add a group for the home directory if it doesn't match the user's group id
         id_homedir=`sudo stat -c %g $USERHOMEDIR`
         if [ $gid != "$gid_homedir" ]; then
            GROUP_ID_EXIST=`getent group $gid_homedir | cut -d: -f3 | wc -l`
	    #echo "GROUP_ID_EXIST is $GROUP_ID_EXIST"
	    if [[ "${GROUP_ID_EXIST}" != "1" ]]; then
               GROUP_NAME_HOMEDIR=group${group_homedir}
	       echo "Adding missing group for home directory ${GROUP_NAME_HOMEDIR}"
               echo "  sudo groupadd -f -g $group_homedir ${GROUP_NAME_HOMEDIR}"
               if [ "${DRYRUN}" != 1 ]; then
                  sudo groupadd -f -g $group_homedir ${GROUP_NAME_HOMEDIR}
	       fi
	    else
               GROUP_NAME_HOMEDIR=`getent group $gid_homedir | cut -d: -f1`
	    fi
	    echo "Adding group of home directory ${GROUP_NAME_HOMEDIR} to user"
            echo "  sudo usermod -a -G ${GROUP_NAME_HOMEDIR}"
            if [ "${DRYRUN}" != 1 ]; then
               sudo usermod -a -G ${GROUP_NAME_HOMEDIR}
	    fi
         fi
         # set password
         if [ ! -z "${pw}" ]; then
            echo "Password requested for ${user_name}:${pw}"
            if [ "${DRYRUN}" != 1 ]; then
               echo ${user_name}:${pw} | sudo chpasswd
	    fi
	 else
            echo "No password requested for ${user_name}"
         fi
      else
         # Neither user exists in /etc/passwd or home directory exists, so
         #   create a user from scratch
	 echo "User does not exist and home directory does not exist"
         if [ "$group_name" != "" ]; then
            GROUP_EXIST=`getent group $group_name | cut -d: -f4 | wc -l`
            #echo "Group exist is ${GROUP_EXIST}"
            if [[ "${GROUP_EXIST}" != "1" ]]; then
               # should add a check that the subdirectory matches the group name?
	       echo "Group does not exist -- creating group"
               echo "  sudo groupadd -f -g ${HACKATHONBASEGROUP} $group_name"
               if [ "${DRYRUN}" != 1 ]; then
                  sudo groupadd -f -g ${HACKATHONBASEGROUP} $group_name
	       fi
               #echo "HACKATHONBASEGROUP=$((HACKATHONBASEGROUP+1))"
            fi
            USERHOMEDIR=${SHARED}/${group_name}/${user_name}
         else
            USERHOMEDIR=${SHARED}/${user_name}
         fi

         id=$((HACKATHONBASEUSER+i))
	 echo "User does not exist -- creating user account"
         echo "  sudo useradd --create-home --skel /users/default --shell /bin/bash --home ${USERHOMEDIR} --uid $id --gid ${gid} ${user_name}"
         echo "  sudo chmod go-rwx  ${USERHOMEDIR}"
         if [ "${DRYRUN}" != 1 ]; then
            sudo useradd --create-home --skel /users/default --shell /bin/bash --home ${USERHOMEDIR} --uid $id --gid ${gid} ${user_name}
            sudo chmod go-rwx  ${USERHOMEDIR}
	 fi
         # set password
         if [ ! -z "${pw}" ]; then
            echo "Password requested for ${user_name}:${pw}"
            if [ "${DRYRUN}" != 1 ]; then
               echo ${user_name}:${pw} | sudo chpasswd
	    fi
	 else
            echo "No password requested for ${user_name}"
         fi
      fi
   fi

   if id "${user_name}" &>/dev/null; then
      VIDEO_GROUP=`id -nG "$user_name" | grep -w video | wc -l`
      AUDIO_GROUP=`id -nG "$user_name" | grep -w audio | wc -l`
      RENDER_GROUP=`id -nG "$user_name" | grep -w render | wc -l`
   else
      VIDEO_GROUP=0
      AUDIO_GROUP=0
      RENDER_GROUP=0
   fi

   if [[ $VIDEO_GROUP != 1 ]] || [[ $AUDIO_GROUP != 1 ]] || [[ $RENDER_GROUP != 1 ]] ; then
      echo "Add groups for access to the GPU (see /dev/dri /dev/kfd)"
      #sudo usermod -a -G video,audio,render,renderalt ${user_name}
      echo "  sudo usermod -a -G video,audio,render ${user_name}"
      if [ "${DRYRUN}" != 1 ]; then
         sudo usermod -a -G video,audio,render ${user_name}
      fi
   fi
   # add the ssh key to the users authorized_keys file
   #sudo chmod a+rwx  ${USERHOMEDIR}
   if [ ! -z "${sshkey}" ]; then
      if sudo test ! -d ${USERHOMEDIR}/.ssh ; then
         echo "Creating .ssh directory for user"
         echo "  sudo mkdir -p  ${USERHOMEDIR}/.ssh"
         echo "  sudo chgrp $group_name ${USERHOMEDIR}/.ssh"
         if [ "${DRYRUN}" != 1 ]; then
            sudo mkdir -p  ${USERHOMEDIR}/.ssh
            sudo chgrp $group_name ${USERHOMEDIR}/.ssh
         fi
      fi
      if sudo test ! -f ${USERHOMEDIR}/.ssh/authorized_keys ; then
         echo "Creating authorized_keys file for user"
         echo "  sudo touch  ${USERHOMEDIR}/.ssh/authorized_keys"
         echo "  sudo chown $user_name ${USERHOMEDIR}/.ssh/authorized_keys"
         echo "  sudo chmod 600 ${USERHOMEDIR}/.ssh/authorized_keys"
         if [ "${DRYRUN}" != 1 ]; then
            sudo touch  ${USERHOMEDIR}/.ssh/authorized_keys
            sudo chown $user_name ${USERHOMEDIR}/.ssh/authorized_keys
            sudo chmod 600 ${USERHOMEDIR}/.ssh/authorized_keys
         fi
      fi

      if sudo test -f ${USERHOMEDIR}/.ssh/authorized_keys ; then
         KEY_EXIST=`sudo grep "${key}" ${USERHOMEDIR}/.ssh/authorized_keys | wc -l`
         if [ "${KEY_EXIST}" == 0 ]; then
            echo "Adding ssh public key for user"
            echo "  sudo chmod 666 ${USERHOMEDIR}/.ssh/authorized_keys"
            echo "  sudo echo "${key}" >> ${USERHOMEDIR}/.ssh/authorized_keys "
            echo "  sudo chmod 600       ${USERHOMEDIR}/.ssh/authorized_keys"
            if [ "${DRYRUN}" != 1 ]; then
               sudo chmod 666 ${USERHOMEDIR}/.ssh/authorized_keys
               sudo echo "${key}" >> ${USERHOMEDIR}/.ssh/authorized_keys 
               sudo chmod 600       ${USERHOMEDIR}/.ssh/authorized_keys
            fi
         fi
      fi
   fi

   if sudo test ! -f ${USERHOMEDIR}/.bash_profile ; then
      echo "Missing .bash_profile file for $user_name. Creating it"
      echo "  sudo cp /users/default/bash_profile ${USERHOMEDIR}/.bash_profile"
      echo "  sudo chown ${user_name} ${USERHOMEDIR}/.bash_profile"
      echo "  sudo chmod 600 ${USERHOMEDIR}/.bash_profile"
      if [ "${DRYRUN}" != 1 ]; then
         sudo cp /users/default/bash_profile ${USERHOMEDIR}/.bash_profile
         sudo chown ${user_name} ${USERHOMEDIR}/.bash_profile
         sudo chmod 600 ${USERHOMEDIR}/.bash_profile
      fi
   fi 
done

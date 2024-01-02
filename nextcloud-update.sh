#!/bin/bash
# this script needs to be run as ROOT (sudo) in order for these actions to be performed properly

NEXTCLOUD_ARCHIVE_URL_ROOT="https://download.nextcloud.com/server/releases"
NEXTCLOUD_ARCHIVE_FILENAME_ROOT="nextcloud"
NEXTCLOUD_ARCHIVE_EXTENSION="zip"
NEXTCLOUD_DESTINATION_FOLDER_PARENT="/usr/share/nginx/html"
SHOULD_BE_ROOT="root"

# user must be root to do all the things. check and exit if not root.
USER=`whoami`
if [ "$USER" != "$SHOULD_BE_ROOT" ]; then
  echo "User is not root, exiting."
  exit 1
fi


# solicit user input: semantic version of Nextcloud to download
echo "Version to download (e.g. 27.0.2): $1"
VERSION_TO_DOWNLOAD=$1

construct_nextcloud_archive_url()
{
  echo "Constructing nextcloud archive url variables ..."
  NEXTCLOUD_ARCHIVE_FILENAME=${NEXTCLOUD_ARCHIVE_FILENAME_ROOT}-${VERSION_TO_DOWNLOAD}.${NEXTCLOUD_ARCHIVE_EXTENSION}
  NEXTCLOUD_ARCHIVE_URL_FULL="${NEXTCLOUD_ARCHIVE_URL_ROOT}/${NEXTCLOUD_ARCHIVE_FILENAME}"
  echo "Constructed NEXTCLOUD_ARCHIVE_FILENAME = $NEXTCLOUD_ARCHIVE_FILENAME ..."
  echo "Constructed NEXTCLOUD_ARCHIVE_URL_FULL = $NEXTCLOUD_ARCHIVE_URL_FULL ..."
}

download_nextcloud_archive()
{
  echo "Downloading $NEXTCLOUD_ARCHIVE_URL_FULL ..."
  wget $NEXTCLOUD_ARCHIVE_URL_FULL -P /tmp
}

extract_and_move_nextcloud_archive()
{
  NEXTCLOUD_DESTINATION_FOLDER="nextcloud-${VERSION_TO_DOWNLOAD}"
  echo "Extracting nextcloud/ from archive and moving to $NEXTCLOUD_DESTINATION_FOLDER ..."
  cd /tmp
  echo "unzipping $NEXTCLOUD_ARCHIVE_FILENAME" 
  unzip -qq $NEXTCLOUD_ARCHIVE_FILENAME
  echo "moving extracted nextcloud/ folder to $NEXTCLOUD_DESTINATION_FOLDER"
  mv nextcloud/ $NEXTCLOUD_DESTINATION_FOLDER
  rm -rf /tmp/$NEXTCLOUD_ARCHIVE_FILENAME
}

move_nextcloud_folder_to_nginx()
{
  echo "Moving $NEXTCLOUD_DESTINATION_FOLDER to $NEXTCLOUD_DESTINATION_FOLDER_PARENT ..."
  cd /tmp
  mv $NEXTCLOUD_DESTINATION_FOLDER $NEXTCLOUD_DESTINATION_FOLDER_PARENT
}

copy_old_nextcloud_configuration()
{
  cd $NEXTCLOUD_DESTINATION_FOLDER_PARENT
  echo "Copying $NEXTCLOUD_DESTINATION_FOLDER_PARENT/nextcloud/config/config.php to ${NEXTCLOUD_DESTINATION_FOLDER_PARENT}/${NEXTCLOUD_DESTINATION_FOLDER}/config ..."
  cp nextcloud/config/config.php ${NEXTCLOUD_DESTINATION_FOLDER_PARENT}/${NEXTCLOUD_DESTINATION_FOLDER}/config
}

setup_nextcloud_symlink()
{
  cd $NEXTCLOUD_DESTINATION_FOLDER_PARENT
  echo "removing nextcloud symlink from previous version of nextcloud"
  unlink nextcloud
  echo "Creating nextcloud symlink to $NEXTCLOUD_DESTINATION_FOLDER ..."
  ln -s $NEXTCLOUD_DESTINATION_FOLDER nextcloud
}

fix_ownership_permissions_of_nextcloud()
{
  echo "changing folder to $NEXTCLOUD_DESTINATION_FOLDER"
  cd $NEXTCLOUD_DESTINATION_FOLDER_PARENT
  echo "Fixing ownership and permissions of $NEXTCLOUD_DESTINATION_FOLDER ..."
  sudo chown -R nginx:nginx $NEXTCLOUD_DESTINATION_FOLDER
  find $NEXTCLOUD_DESTINATION_FOLDER -type d -exec chmod 750 {} \;
  find $NEXTCLOUD_DESTINATION_FOLDER -type f -exec chmod 640 {} \;
}

setup_new_nextcloud_version()
{
  echo "changing folder to $NEXTCLOUD_DESTINATION_FOLDER_PARENT/nextcloud"
  cd $NEXTCLOUD_DESTINATION_FOLDER_PARENT/nextcloud
  echo "Turning on maintenance mode ..."
  sudo -u nginx php occ maintenance:mode --on
  echo "Executing occ upgrade ..."
  sudo -u nginx php occ upgrade
  echo "Turning off maintenance mode ..."
  sudo -u nginx php occ maintenance:mode --off
}


restart_services()
{
  echo "Restarting php8.2-fpm and nginx services ..."
  systemctl restart php8.2-fpm nginx
}

# Sleeps were added for debugging - they can be removed if you care to remove them.
construct_nextcloud_archive_url
sleep 5
download_nextcloud_archive
sleep 5
extract_and_move_nextcloud_archive
sleep 5
move_nextcloud_folder_to_nginx
sleep 5
copy_old_nextcloud_configuration
sleep 5
setup_nextcloud_symlink
fix_ownership_permissions_of_nextcloud
setup_new_nextcloud_version
restart_services

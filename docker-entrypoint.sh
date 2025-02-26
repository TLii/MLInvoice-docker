#!/usr/bin/env bash

# Unofficial MLInvoice containers
# Copyright (C) 2024 Tuomas Liinamaa <tlii@iki.fi>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# Partially derived from Docker Hub's official images;
# Copyright 2014 Docker, Inc.set -e

set -Eeo pipefail

user=www-data
group=www-data

# Test for necessary environment variables and exit if missing crucial ones.
	[[ -z $DATABASE_NAME ]] && (echo "ERROR: you need to set DATABASE_NAME to continue"; exit 78)
	[[ -z $DATABASE_USER ]] && (echo "ERROR: you need to set DATABASE_USER to continue"; exit 78)
	[[ -z $DATABASE_PASSWORD ]] && (echo "ERROR: you need to set DATABASE_PASSWORD to continue"; exit 78)
	[[ -z $DATABASE_HOST ]] && (echo "ERROR: you need to set DATABASE_HOST to continue"; exit 78)
	[[ -z $SITE_URL ]] && { echo "WARN: no SITE_URL set, using localhost" && SITE_URL='localhost'; }
echo >&2 "Necessary environment variables set, continuing..."

# Install entrypoint dependencies
echo >&2 "Installing entrypoint dependencies..."
curl https://raw.githubusercontent.com/fsaintjacques/semver-tool/master/src/semver > /usr/local/bin/semver
chmod o+rx /usr/local/bin/semver

# Setup correct user; (c) Docker, Inc
	if [[ "$1" == apache2* ]] || [ "$1" = 'php-fpm' ]; then
		uid="$(id -u)"
		gid="$(id -g)"
		if [ "$uid" = '0' ]; then
			case "$1" in
				apache2*)
					user="${APACHE_RUN_USER:-www-data}"
					group="${APACHE_RUN_GROUP:-www-data}"
					echo >&2 "This is an apache2 image."
					# strip off any '#' symbol ('#1000' is valid syntax for Apache)
					pound='#'
					user="${user#$pound}"
					group="${group#$pound}"
					;;

				*) # php-fpm
					user='www-data'
					group='www-data'
					echo >&2 "This is a php-fpm image."
					;;
			esac
		else
			user="$uid"
			group="$gid"
		fi
	fi

# Create necessary apache2 config changes to maintain directory similarities
	if [[ "$1" == apache2* ]]; then
	echo >&2 "Modifying apache2 config file to recognixe $SITE_URL..."
		sed -i -e "s|www\.example\.com|$SITE_URL|g" -e "s|localhost|$SITE_URL|g" /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-available/default-ssl.conf;
		sed -i /etc/apache2/conf-available/docker-php.conf;
	fi

# Test for existing installation and install as necessary; original code by Docker, Inc, edited by TLii
current_version=$(grep softwareVersion /var/www/html/version.php  | sed "s|$softwareVersion.*'\(.*\)';|\1|")
src_version=$(grep softwareVersion  /usr/src/mlinvoice/version.php | sed "s|$softwareVersion.*'\(.*\)';|\1|")

if [[ -f /var/www/html/version.php ]]; then
	VERSIONS=$(semver compare $current_version $src_version );
else
	# No installation found
	VERSIONS=-2;
fi

if { [[ ! -f /var/www/html/install.lock ]] || [[ ! -f /var/www/html/config.php ]]; } && [[ $VERSIONS -le 0 ]]; then

    cd "/var/www/html"

    # Correct permissions if necessary
	if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
		chown "$user:$group" .
	fi
	[[ $VERSIONS == -1 ]] && echo >&1 "MLInvoice not found in $PWD - copying now..."
	[[ $VERSIONS == -1 ]] && echo >&2 "A new version of MLInvoice found, updating files..."
	[[ $VERSIONS == 0 ]] && echo >&1 "MLInvoice version is the same as installed."

	if [ -n "$(find . -mindepth 1 -maxdepth 1)" ]; then
		echo >&1 "WARNING: $PWD is not empty! (copying anyhow)"
	fi

	sourceTarArgs=(
		--create
		--file -
		--directory /usr/src/mlinvoice
		--owner "$user" --group "$group"
	)
	targetTarArgs=(
		--extract
		--file -
	)
	if [ "$uid" != '0' ]; then
		# avoid "tar: .: Cannot utime: Operation not permitted" and "tar: .: Cannot change mode to rwxr-xr-x: Operation not permitted"
		targetTarArgs+=( --no-overwrite-dir )
	fi

	# Exclude existing config file.
	[[ -f ./config.php ]] && sourceTarArgs+=( --exclude "./config.php");

	# loop over modular content in the source, and if it already exists in the destination, exclude it
	# for contentPath in \
    # /usr/src/mlinvoice/modules/*
	# ; do
	# 	# Check if contentPath exists
	# 	contentPath="${contentPath%/}"
	# 	[ -e "$contentPath" ] || continue
	# 	# If contentPath exists in source and application directory, exclude it from overwrite
	# 	contentPath="${contentPath#/usr/src/mlinvoice/}"
	# 	if [ -e "$PWD/$contentPath" ]; then
	# 		echo >&1 "INFO: '$PWD/$contentPath' exists. Updating only with newer content."
	# 		#TODO: Make this check if update is in fact newer and patchable.
	# 		sourceTarArgs+=( --exclude "./$contentPath" )
	# 	fi
	# done

	tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"

	# # See if modules need updating; save backups to <install_dir>/upload/docker-upgrade-backups/
	# mkdir -p $PWD/backup/docker-upgrade-backups
	# for modulePath in \
	# ; do
	# 	modulePath="${modulePath#/usr/src/mlinvoice/}"
	# 	rsync -q -r -b -t -u --backup-dir=$PWD/backup/docker-upgrade-backups --update usr/src/mlinvoice/$modulePath $PWD/$modulePath
	# done
	[[ -n $CREATE_DATABASE ]] && mysql --user=$DATABASE_USER --password=$DATABASE_PASSWORD --host=$DATABASE_HOST --database=$DATABASE_NAME < /var/www/html/create_database.sql
	touch /var/www/html/install.lock
	echo >&1 "Complete! MLInvoice has been successfully copied to $PWD"
else
	echo >&1 "MLInvoice is installed or a newer version was found. Not copying any files."
fi

# Replace config directives
echo >&2 Replacing config directives with current environment variables...
sed -i -r "s/define\('_DB_SERVER_', '.*?'\);/define('_DB_SERVER_', '$DATABASE_HOST');/" /var/www/html/config.php.sample && \
sed -i -r "s/define\('_DB_USERNAME_', '.*?'\);/define('_DB_USERNAME_', '$DATABASE_USER');/" /var/www/html/config.php.sample && \
sed -i -r "s/define\('_DB_PASSWORD_', '.*?'\);/define('_DB_PASSWORD_', '$DATABASE_PASSWORD');/" /var/www/html/config.php.sample
sed -i -r "s/define\('_DB_NAME_', '.*?'\);/define('_DB_NAME_', '$DATABASE_NAME');/" /var/www/html/config.php.sample
if [[ -n $ENCRYPTION_KEY ]]; then
    sed -i -r "s/define\('_ENCRYPTION_KEY_', '.*?'\);/define('_ENCRYPTION_KEY_', '$ENCRYPTION_KEY');/" /var/www/html/config.php.sample;
	echo >&1 Using a predefined encryption key.
else
    ENCRYPTION_KEY=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 132 ; echo '')
    sed -i -r "s/define\('_ENCRYPTION_KEY_', '.*?'\);/define('_ENCRYPTION_KEY_', '$ENCRYPTION_KEY');/" /var/www/html/config.php.sample;
	echo >&1 Using a randomized encryption key. Keep in mind that if you lose your config file, this key is lost!
fi
if [[ -n $FORCE_HTTPS ]]; then
    sed -i -r "s/\/\/define\('_FORCE_HTTPS_', '.*?'\);/define('_FORCE_HTTPS_', true);/" /var/www/html/config.php.sample
	echo >&1 "Forcing https in app level"
fi

if [[ -n $DEVELOPER_MODE ]]; then
	ECHO >&2 "Use developer config for php..."
	mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini";
fi

echo >&2 "Bringing up container with arguments: '$*'"

# Wrap up with executing correct process with correct arguments
if [[ "$1" == apache2* ]] && [ "${1#-}" != "$1" ]; then
	echo >&2 "All done, running apache2 next..."
	set -- apache2-foreground "$@"
elif [ "${1#-}" != "$1" ]; then
	echo >&2 "All done, running php-fpm next..."
	set -- php-fpm "$@"
else
	echo >&1 "All done, running provided command."
fi

exec "$@"
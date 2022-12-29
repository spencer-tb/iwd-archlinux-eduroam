#!/bin/sh

EDUROAM_FILENAME="/var/lib/iwd/eduroam.8021x"

anonymous_identity=""
certificate_file=""
server_domain=""
user_identity=""
user_password=""

# print_help {{{1

print_help ()
{
cat << EOF
iwd-eduroam
===========
A POSIX shell assistant to configure eduroam with iwd.
------------------------------------------------------

:: DESCRIPTION

iwd-eduroam is a small assistant that helps you configure eduroam for iwd. It
creates and populates '/var/lib/iwd/eduroam.8021x' with the information you
give it.

       +--------------------------------------------------------------+
       |                       !!! WARNING !!!                        |
       |  This program requires 'sudo' privileges to write files      |
       |  into their destination. It won't ask for them anywhere else |
       |  and uses the minimum viable number of superuser commands.   |
       +--------------------------------------------------------------+

:: USAGE

Call iwd-eduroam.sh: ./iwd-eduroam.sh and enter your credentials:
 - e.g s1234567@ed.ac.uk and password

This will create the  '/var/lib/iwd/eduroam.8021x' iwd configuration file.
Now your should be able to connect to eduroam running 'iwctl station wlan0 connect "eduroam"'.


EOF
}
# }}}1

# cert_is_a_script {{{1
# Checks whether the certificate path corresponds to an official eduroam
# installation script present in the working directory and whether it contains
# a certificate.

cert_is_a_script ()
{
	certificate_path="$(basename "$1")"
	found=1

	if echo "$certificate_path" | grep "\.py$" > /dev/null && \
		[ "$(find . -maxdepth 1 -name "$certificate_path" | wc -l)" -gt 0 ] > /dev/null
	then
		if grep -- "-----BEGIN CERTIFICATE-----" "$certificate_path" > /dev/null
		then
			echo "Found certificate in script $certificate_path" > /dev/stderr
			found=0
		else
			echo "Certificate not found in script $certificate_path" > /dev/stderr
		fi
	fi

	return $found
}
# }}}1

# cert_is_in_directory {{{1
# Checkts whether the certificate path corresponds to a file present in the
# working directory and whether it contains a certificate.

cert_is_in_directory ()
{
	certificate_path="$(basename "$1")"
	found=1

	if [ "$(find . -maxdepth 1 -name "$certificate_path" | wc -l)" -gt 0 ] > /dev/null
	then
		if sed 'q' "$certificate_path" | grep -- "-----BEGIN CERTIFICATE-----" > /dev/null
		then
			echo "Found certificate file in $certificate_path" > /dev/stderr
			found=0
		else
			echo "File $certificate_path is not a certificate" > /dev/stderr
		fi
	fi

	return $found
}
# }}}1

# cert_is_in_system {{{1
# Checks whether the certificate path corresponds to a file located in
# /etc/ssl/certs/ and whether the certificate exists in the system.

cert_is_in_system ()
{
	certificate_path="$1"
	found=1

	if echo "$certificate_path" | grep "^/etc/ssl/certs/" > /dev/null
	then
		if (find "$certificate_path") > /dev/null
		then
			echo "Found certificate in $certificate_path" > /dev/stderr
			found=0
		else
			echo "Certificate not found in $certificate_path" > /dev/stderr
		fi
	fi

	return $found
}
# }}}1

# check_args {{{1
# Prints the help text if the number of arguments is incorrect or if the user
# asks for help with the script.

check_args ()
{
	if [ "$#" != 1 ]
	then
		print_help
		exit 1
	fi

	if [ "$1" = "--nocert" ]
	then
	    echo "Creating config with no certificate."
        certificate_file=""
	fi

	if [ "$1" = "-h" ] || [ "$1" = "--help" ]
	then
		print_help
		exit 0
	fi
}
# }}}1

# confirm {{{1
# Queries the user for a yes/no question. If "yes" or "no" are passed before the
# question string, that answer will be the default (i.e. the one answered if the
# user inputs an empty string. This function loops until the user inputs a
# correct answer.

confirm ()
{
	answer=-1

	case "$1" in
	[Yy][Ee][Ss])
		printf "\033[1;32m:: \033[0m%s? \033[1;32m[Y/n]:\033[0m " "$2"
	;;
	[Nn][Oo])
		printf "\033[1;31m:: \033[0m%s? \033[1;31m[y/N]:\033[0m " "$2"
	;;
	*)
		printf "\033[1;33m:: \033[0m%s? \033[1;33m[y/n]:\033[0m " "$1"
	;;
	esac

	while [ $answer -eq -1 ]
	do
		read -r yn

		case $yn in
		[Yy]*)
			answer=0
		;;
		[Nn]*)
			answer=1;
		;;
		*)
			case "$1" in
			[Yy][Ee][Ss])
				answer=0
			;;
			[Nn][Oo])
				answer=1
			;;
			esac
		;;
		esac
	done

	return $answer
}
# }}}1

# get_certificate_type {{{1
# Checks whether the certificate path provided is for a certificate already
# installed in the system ("SYSTEM"), an official eduroam installation script
# ("SCRIPT") or a certificated located in the working directory ("LOCAL"). It
# echoes the answer to its caller, so all subroutines should echo all their
# text into /dev/null to avoid polluting the output unless they are showing it
# to the user, in which case they should use /dev/stderr.

get_certificate_type ()
{
	certificate_path="$1"
	certificate_type=""

	if cert_is_in_system "$certificate_path"
	then
		certificate_type="SYSTEM"

	elif cert_is_a_script "$certificate_path"
	then
		certificate_type="SCRIPT"

	elif cert_is_in_directory "$certificate_path"
	then
		certificate_type="LOCAL"
	fi

	echo "$certificate_type"
}
# }}}1

# find_or_install_certificate {{{1
# Gets the type of the certificate provided by the certificate path and, if its
# not a system certificate, it tries to find it and asks the user to install it
# if it's not found. If no certificate is found, it aborts the program.

find_or_install_certificate ()
{
	certificate_path="$1"
	certificate_type="$(get_certificate_type "$certificate_path")"

	if [ "$certificate_type" = "LOCAL" ]
	then
		certificate_string="$(sed 's/\r//g' "$certificate_path")"
		find_or_install_certificate_from_string "$certificate_string" "$certificate_path"

	elif [ "$certificate_type" = "SCRIPT" ]
	then
		certificate_string="$(\
			sed 's/\r//g' "$(basename "$certificate_path")" | \
			tr '\n' '|' | \
			sed \
			-e 's/.\+\(-----BEGIN CERTIFICATE-----.\+\)/\1/' \
				-e 's/\(.\+-----END CERTIFICATE-----\).\+/\1/' \
				-e 's/|\|$/\n/g' \
		)"
		find_or_install_certificate_from_string "$certificate_string" "$certificate_path"

	elif [ "$certificate_type" != "SYSTEM" ]
	then
		echo "Aborting..." > /dev/stderr
		exit 1
	fi
}
# }}}1

# find_or_install_certificate_from_string {{{1
# Checks whether the certificate passed as a string in the first argument is
# already installed in your system (i.e. there's a file in /etc/ssl/certs/ with
# the same first line, which is enough to check that their contents are the
# same). If it's installed, it sets that as the certificate file for the eduroam
# config file. If it's not, it prompts the user to install it. If the certificate
# is found and is a symbolic link, the link is followed to find the actual
# location of the certificate.

find_or_install_certificate_from_string ()
{
	certificate_string="$1"
	certificate_path="$(basename "$2")"
	certificate_first_line="$(echo "$certificate_string" | sed -e '1d;q' -e 's/\r//g')"

	certificate_file="$(\
		grep -R "$certificate_first_line" /etc/ssl/certs/ | \
		sed -E 's/:.+//g' | sed 'q'
	)"

	if [ "$certificate_file" = "" ]
	then
		echo "Your certificate was not found in your system."

		if confirm "YES" "Install certificate in /etc/ssl/certs/"
		then
			certificate_file="/etc/ssl/certs/$(echo "$certificate_path" | sed 's/\..*$/.crt/')"
			sed 's/\r//g' "$certificate_path" | sudo tee "$certificate_file" > /dev/null
		fi

		echo "Your certificate has been installed in $certificate_file"

	elif [ -f "$certificate_file" ]
	then
		if [ -L "$certificate_file" ]
		then
			certificate_file="$(readlink -f "$certificate_file")"
		fi

		echo "Found the same certificate already installed in $certificate_file"
	fi
}
# }}}1

# print_iwd_config {{{1
# Echoes the contents to be written into the eduroam config file complete with
# the information supplied by the user.

print_iwd_config ()
{
	echo "[Security]"
	echo "EAP-Method=PEAP"
	echo "EAP-Identity=$anonymous_identity"
	if [ "$certificate_file" != "" ]
	then
        echo "EAP-PEAP-CACert=$certificate_file"
	fi
	echo "EAP-PEAP-Phase2-Method=MSCHAPV2"
	echo "EAP-PEAP-Phase2-Identity=$user_identity"
	echo "EAP-PEAP-Phase2-Password=$user_password"
	if [ "$server_domain" != "" ]
	then
	    echo "EAP-PEAP-ServerDomainMask=*.$server_domain"
	fi
	echo ""
	echo "[Settings]"
	echo "AutoConnect=true"
}
# }}}1

# query_user {{{1
# Asks the user for a data string and returns the answer. The query is shown in
# bold text. If "HIDDEN" is passed as second argument, the users input won't be
# shown. This is useful to conceal password input.

query_user ()
{
	query_string="$1"
	hidden_answer=0

	if [ $# -gt 1 ] && [ "$2" = "HIDDEN" ]
	then
		hidden_answer=1
	fi

	printf "\033[0;1m%s: \033[0m" "$query_string" > /dev/stderr

	[ $hidden_answer -eq 1 ] && stty -echo
	read -r answer
	[ $hidden_answer -eq 1 ] && stty echo && (printf "\n") > /dev/stderr

	echo "$answer"
}
# }}}1

# main {{{1
# Checks if the arguments are correct and whether the certificate is intalled in
# your system, then prompts the user to insert the connection credentials and
# installs the configuration file.

main ()
{
	echo ""
	echo "Please enter your eduroam credentials as instructed by your university:"

	user_identity="$(query_user "User identity")"
	anonymous_identity="$user_identity"
	user_password="$(query_user "User password" "HIDDEN")"

	print_iwd_config | sudo tee "$EDUROAM_FILENAME"
}

# }}}1

main "$@"


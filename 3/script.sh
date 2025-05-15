#!/usr/bin/env bash

USAGE_LIMIT=15

Help()
{
	echo "Script to send email in case of high disk usage on host."
	echo
	echo "Syntax: script.bash [-h] [-l <login>] [-p <password>] -s <FQDN|IPv4>[:port]"
	echo "options:"
	echo "h     Print this Help."
	echo "l     Login name for SMTP server."
	echo "p     Password for login."
	echo "s     SMTP server FQDN or IPv4 address"
	echo
}

while getopts ":hs:l:p:" option; do
	case $option in
		h)
			Help
			exit 0;;
		s)
			if [[ ! $OPTARG =~ ^[^-].*$ ]]; then
				echo "Error: Server option (-s) must have valid argument" >&2
				exit 1
			fi
			SERVER=${OPTARG};;
		l)
			LOGIN=${OPTARG};;
		p)
			PASSWORD=${OPTARG};;
		:)
			echo "Error: -${OPTARG} option need argument" >&2
			exit 1;;
		\?)
			echo "Error: Invalid option ${OPTARG}" >&2
			exit 1;;
	esac
done

if ! [[ $SERVER ]]; then
	echo "Error: Server option -s must be defined" >&2
	exit 1
elif (($# % 2)); then
	echo "Error: all options must have arguments" >&2
	exit 1
fi

DEVS=$(df -l -x tmpfs -x overlay --output=source,target,pcent \
| awk "NR>1 && substr(\$3,0,length(\$3) -1) + 0 > ${USAGE_LIMIT} \
{ printf(\" - Device: %s\n   Mount point: %s\n   Usage: %s\n\",\$1,\$2,\$3) }")

if [[ $DEVS ]]; then
	#Install required utilities
	set -e
	if ! command -v msmtp >/dev/null 2>&1; then
		for pm in apt apt-get dnf yum; do
			if command -v $pm >/dev/null 2>&1; then
				if [[ ${pm} =~ ^(apt|apt-get)$ ]] && ${pm} show msmtp >/dev/null 2>&1; then 
					export DEBIAN_FRONTEND=noninteractive
					${pm} update > /dev/null
					${pm} install msmtp -y > /dev/null
				elif [[ ${pm} =~ ^(dnf|yum)$ ]] && ${pm} info msmtp >/dev/null 2>&1; then
					${pm} install msmtp -y > /dev/null
				else
					echo "Can't find msmtp package in available repos: ${pm}" >&2
					exit 1
				fi
				break
			fi
		done
	fi
	set +e


	#Create temporary config file for msmtp
	touch /tmp/msmtp.conf
	chmod 600 $_
	echo "account tmp" > /tmp/msmtp.conf
	echo "host ${SERVER%:*}" >> /tmp/msmtp.conf
	case ${SERVER##*:} in
		465)
			echo 'port 465' >> /tmp/msmtp.conf
			echo 'tls on' >> /tmp/msmtp.conf
			echo 'tls_starttls off' >> /tmp/msmtp.conf
			echo 'tls_certcheck off' >> /tmp/msmtp.conf;;
		587)
			echo "port 587" >> /tmp/msmtp.conf
			echo "tls on" >> /tmp/msmtp.conf
			echo 'tls_starttls on' >> /tmp/msmtp.conf
			echo 'tls_certcheck off' >> /tmp/msmtp.conf;;
	esac
	if [[ $LOGIN ]]; then 
		echo "auth on" >> /tmp/msmtp.conf
		echo "user ${LOGIN}" >> /tmp/msmtp.conf
		if [[ $PASSWORD ]]; then echo "password ${PASSWORD}" >> /tmp/msmtp.conf; fi
	fi

	#Send mail
	msmtp -C /tmp/msmtp.conf --read-envelope-from -a tmp -t <<-EOF
		From: ${LOGIN}
		To: ${LOGIN}
		Subject: Space usage > ${USAGE_LIMIT}% on $(hostname -f)
		Following devices have space usage > ${USAGE_LIMIT}%:
		$DEVS
	EOF

	rm /tmp/msmtp.conf
fi

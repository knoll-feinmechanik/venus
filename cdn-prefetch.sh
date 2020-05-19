#!/bin/bash
#
# Script to send a trigger to the CDN to download the installation images to all caches nodes.
#
# Wiebe Cazemier <wiebe@ytec.nl>. Approved by 'shellcheck'.

password_filepath="$HOME/.cdnetworks-victronci-api-key"
docroot="/var/www/victron_www"
sshuser="victron_www"
originserver="updates-origin.victronenergy.com"

if [[ ! -f "$password_filepath" ]]; then
  echo "The CD Networks API key for cache pre-fetching was not found in '$password_filepath'. Ask Ytec (Wiebe) to give it to you."
  exit 1
fi

chmod 600 "$password_filepath"

if ! which curl &> /dev/null; then
  echo "install curl"
  exit 1
fi

if ! which openssl &> /dev/null; then
  echo "install openssl"
  exit 1
fi

if [[ "$1" == "--check-mode" ]]; then
  exit 0
fi

echo ""
echo "Sending trigger to CDN to download installation images to all cache nodes..."
echo ""

set -u

docroot=$(echo "$docroot" | sed -e 's#/$##')
urls=$(ssh "$sshuser@$originserver" "find '$docroot/feeds/venus/' -type l -print0 | xargs -0 -I '{}' echo '{}' | sed -e 's#$docroot#https://updates.victronenergy.com#' | sed -e 's/ /%20/g'")

OIFS="$IFS"
IFS=$'\n'
comma=""
all_urls=""
for url in $urls; do
  all_urls="$all_urls ${comma} \"$url\" "
  comma=","
done
IFS="$OIFS"

usename='victronci'
apikey=$(cat "$password_filepath")
date=$(LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8" date -u "+%a, %d %b %Y %H:%M:%S GMT")
password=$(echo -en "$date" | openssl dgst -sha1 -hmac "$apikey" -binary | openssl enc -base64)

curl_output=$(curl --silent --include --url "https://api.cdnetworks.com/ccm/fetch/ItemIdReceiver" \
  --user "$usename:$password" \
  --header "Date: $date" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --header "Expect:" \
  --user-agent "$0" \
  --data "{ \"urls\" : [ ${all_urls} ] }"
)

curl_result=$?

if [[ "$curl_result" -ne 0 ]]; then
  echo "Curl itself failed. Probably connection error?"
  echo
  echo "$curl_output"
  exit 1
fi

first_line=$(echo "$curl_output" | head -n 1)

if [[ ! "$first_line" == *200* ]]; then
  echo "Not HTTP 200. Failing"
  echo
  echo "$curl_output"
  echo
  echo "Again, not HTTP 200. Failing"
  exit 1
fi

if ! echo "$curl_output" | grep --quiet --extended-regexp --ignore-case '"code".{0,4}1'; then
  echo "Code 1 not found, must be an error then"
  echo
  echo "$curl_output"
  echo
  echo "Again, code 1 not found, must be an error then"
  exit 1
fi

echo
echo "$curl_output"
echo
echo "CDN pre-fetching API call seemingly successful"
exit 0

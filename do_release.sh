#!/bin/bash

DEPLOY=deploy/venus
REMOTE=victron_www@updates-origin.victronenergy.com
D=/var/www/victron_www/feeds/venus/
FEED="$REMOTE:$OPKG"

CURRENT_FILEPATH=$(readlink --canonicalize "$0")
CURRENT_DIR=$(dirname "$CURRENT_FILEPATH")
PREFETCH_SCRIPT="$CURRENT_DIR/cdn-prefetch.sh"

if [ $# -eq 0 ]; then
	echo "Usage: $0 release|candidate|testing"
	exit 1
fi

function release ()
{
	from="$D$1"
	to="$D$2"
	exclude=""

	prefetch_cache="false"

	if [[ "$2" == "release" || "$2" == "candidate" ]]; then
		prefetch_cache="true"
	fi

	if "$prefetch_cache" ; then
		if ! "$PREFETCH_SCRIPT" --check-mode; then
			echo "CDN prefetch conditions not met"
			exit 1
		fi
	fi

	echo $from $to
	ssh $REMOTE "if [ ! -d $to ]; then mkdir $to; fi"

	# upload the files
	ssh $REMOTE "rsync -v $exclude -rpt --no-links $from/ $to"

	# thereafter update the symlinks and in the end delete the old files
	ssh $REMOTE "rsync -v $exclude -rptl $from/ $to"

	# keep all released images
	if [ "$2" = "release" ]; then
		exclude="$exclude --exclude=images/"
	fi

	ssh $REMOTE "rsync -v $exclude -rpt --delete $from/ $to"

	if "$prefetch_cache" ; then
		$PREFETCH_SCRIPT
	fi
}

case $1 in
	release )
		echo "Candidate -> Release"
		release candidate release
		;;
	candidate )
		echo "Testing -> Candidate"
		release testing candidate
		;;
	testing )
		echo "Develop -> Testing"
		release develop testing
		;;
	skip-candidate )
		echo "Testing -> Release (skips candidate!)"
		read -n1 -r -p "Press any key to continue... Or CTRL-C to abort"
		release testing release
		;;
	skip-testing )
		echo "Develop -> Candidate (skips testing!)"
		read -n1 -r -p "Press any key to continue... Or CTRL-C to abort"
		release develop candidate
		;;
	*)
		echo "Not a valid parameter"
		;;
esac

# vim: noexpandtab:shiftwidth=2:tabstop=2:softtabstop=0:textwidth=110

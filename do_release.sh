#!/bin/bash
#
# Venus downloads from https://updates.victronenergy.com/, which is hosted by CD Networks. Because of that, it
# can't be used by SSH to connect to. Therefore, we need to connect to the 'origin' directly, hence the
# different DNS name in "$REMOTE"

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
			echo
			echo "CDN prefetch conditions not met. Prefetching preloads the SWU images to hundreds of nodes of the"
			echo "content delivery network, allowing much faster download. Without pre-fetching, the images"
			echo "Will still be downloaded on-demand, so aside from download speed, users won't notice it."
			read -r -p "Continue without prefetching? (y/n): " answer

			if [[ $answer == "y" ]]; then
				prefetch_cache="false"
			else
				exit 1
			fi
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

		if [[ $? -ne 0 ]]; then
			echo
			echo "CD Networks pre-fetching reported a failure. Pre-fetching is done after the release, so this"
			echo "error does NOT mean the release failed."
		fi
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

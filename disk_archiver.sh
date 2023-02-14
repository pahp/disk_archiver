#!/bin/bash

function do_ddrescue
{
	echo "Attempting ddrescue..."
	ddrescue -d -D -b 2048 -r4 -v /dev/${DEV} $ISONAME ${DISCNAME}.map
	if ! ddrescue_success_test
	then
		echo "ddrescue unsuccessful -- trying harder! (direct mode)"

		ddrescue -d -b 2048 -r4 -v /dev/${DEV} $ISONAME ${DISCNAME}.map
		if ! ddrescue_success_test
		then
			echo "direct mode still unsuccessful."
			echo "I give up. :("
			exit 1
		else
			echo "direct mode finished successfully!"
		fi
	else
		echo "ddrescue (non-direct) finished successfully!"
	fi

}

function ddrescue_success_test
{
	# test to see if ddrescue got everything
	if ! ddrescuelog -D ${DISCNAME}.map
	then
		echo "ddrescue was not able to fully recover this disc."
		return 1
	else
		echo "ddrescue was able to fully recover this disc! Deleting map."
		ddrescuelog -d ${DISCNAME}.map
		return 0
	fi

}


function check_and_compress
{
	ILOG=${ISONAME}.isolyzer
	isolyzer ${ISONAME} > $ILOG
	if ! grep "<sizeDifference>0</sizeDifference>" $ILOG
	then
		echo "Integrity check failed! (probably not a problem)"
		echo "Check isolyzer log in $ILOG."
	fi

	# checks passed -- cleaning up and compressing

	echo "Making archive directory..."
	if [[ ! -d ${DISCNAME} ]]
	then
		mkdir -v ${DISCNAME}
	else
		echo "Directory already exists."
		exit 1
	fi
	
	echo "Taking hash of the iso..."
	sha512sum $DISCNAME.iso | tee $DISCNAME/$DISCNAME.sha512sum

	# mv iso into directory
	mv $ISONAME $DISCNAME
	mv $ILOG $DISCNAME

	# save map in directory if it exists
	if [[ -f ${DISCNAME}.map ]]
	then
		mv ${DISCNAME}.map $DISCNAME
	fi
	
	echo "Disc complete! You may reuse device $DEV now."
	
	eject $DEV

	echo "Compressing $DISCNAME.tar.xz..."
	if ! tar cvJf ${DISCNAME}.tar.xz ${DISCNAME}
	then
		echo "Tar failed! -- manual cleanup required."
		exit 1
	else
		echo "Removing $DISCNAME (successful archive)"
		rm -rfv ${DISCNAME}
	fi

	echo "Archive successful. ($DEV - $DISCNAME)"
	exit 0
}

function usage
{
echo "Usage: ./disk_archiver.sh srX iso name with spaces"
echo
echo "disk_archiver.sh will use dd to read srX to the name specified"
echo "with spaces replaced by underscores. If successful, the iso will"
echo "Be zipped with xz. If unsuccessful, you can optionally rm it."
exit 1
}

if [[ -z $1 ]]
then
	usage
fi

DEV=$1
echo "Device is: $DEV"

DISCNAME="$(echo "${@:2}" | sed -r 's/ /_/g')"
ISONAME=${DISCNAME}.iso
RLOG=$(mktemp)

echo "Discname: $DISCNAME"
echo "ISO name will be: $ISONAME"
sleep 2

# umount the disc if it is mounted
if df | grep $DEV
then
	echo "Unmounting /dev/$DEV..."
	if !  umount /dev/$DEV
	then
		echo "Couldn't umount /dev/$DEV. Quitting."
		exit 1
	fi
fi

# check to see if there's a map file from ddrescue
if [[ -f ${DISCNAME}.map && -f $ISONAME ]]
then
	# ddrescue has already been run
	echo "Attempting to continue a previous ddrescue run..."
	do_ddrescue
else

	# this is a new attempt

	# first, try readom and keep the log
	readom retries=4 dev=/dev/${DEV} f=$ISONAME 2>&1 | tee $RLOG

	# check the log for errors because readom always returns 0 :<
	if grep -i "input/output error" $RLOG
	then
		echo "*** ERROR ***"
		rm $ISONAME
		echo

		# readom failed, so try ddrescue...
		do_ddrescue
		
	else
		echo "readom successful!"
		rm $RLOG
	fi
fi

echo "*** SUCCESS ***"
check_and_compress
echo

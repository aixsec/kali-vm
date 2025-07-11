#!/bin/sh

set -eu

fail() { echo "$@" >&2; exit 1; }
usage() { fail "Usage: $(basename $0) VHDX"; }

# Validate arguments

[ $# -eq 1 ] || usage

disk_path=$1

[ ${disk_path##*.} = vhdx ] || fail "Invalid input file '$disk_path'"

description_template=$RECIPEDIR/scripts/templates/vm-description.txt
machine_templace=$RECIPEDIR/scripts/templates/vm-definition.xml

# Prepare all the values

disk_file=$(basename $disk_path)
name=${disk_file%.*}

arch=${name##*-}
[ "$arch" ] || fail "Failed to get arch from image name '$name'"
version=$(echo $name | sed -E 's/^kali-linux-(.+)-.+-.+$/\1/')
[ "$version" ] || fail "Failed to get version from image name '$name'"

case $arch in
    amd64)
        platform=x64
        ;;
    *)
        fail "Invalid architecture '$arch'"
        ;;
esac

# Create the description

description=$(sed \
    -e "s|%date%|$(date --iso-8601)|g" \
    -e "s|%platform%|$platform|g" \
    -e "s|%version%|$version|g" \
    $description_template)

# Create the .xml file

output=${disk_path%.*}.xml

sed \
    -e "s|%DiskFile%|$disk_file|g" \
    -e "s|%MachineName%|$name|g" \
    $machine_templace > $output

awk -v r="$description" '{ gsub(/%Description%/,r); print }' $output > $output.1
mv $output.1 $output

unmatched_patterns=$(grep -E -n "%[A-Za-z_]+%" $output || :)
if [ "$unmatched_patterns" ]; then
    echo "Some patterns were not replaced in '$output':" >&2
    fail "$unmatched_patterns"
fi

#!/bin/bash

set -eu

if ! [ -e /etc/default/keyboard ]; then
    echo "ERROR: keyboard layout could not be set and defaults to us!"
    exit 0
fi

IFS='/' read -r layouts model variants options <<< "$1"

if [[ -n "$layouts" ]]; then
    valid_layouts=$(cat /usr/share/X11/xkb/rules/xorg.lst | sed -n '/^! layout/,/^$/p' | awk 'NR > 1 {print $1}')
    IFS=',' read -r -a layout_array <<< "$layouts"
    for layout in "${layout_array[@]}"; do
        if ! echo "$valid_layouts" | grep -q -w "$layout"; then
            echo "ERROR: Invalid layout: $layout"
            exit 1
        fi
    done
    sed -i -E "s/XKBLAYOUT=\".*\"/XKBLAYOUT=\"$layouts\"/" /etc/default/keyboard
    echo "INFO: Set layouts to $layouts"
fi

if [[ -n "$model" ]]; then
    valid_models=$(cat /usr/share/X11/xkb/rules/xorg.lst | sed -n '/^! model/,/^$/p' | awk 'NR > 1 {print $1}')
    if ! echo "$valid_models" | grep -q -w "$model"; then
        echo "ERROR: Invalid model: $model"
        exit 1
    fi
    sed -i -E "s/XKBMODEL=\".*\"/XKBMODEL=\"$model\"/" /etc/default/keyboard
    echo "INFO: Set model to $model"
fi

if [[ -n "$variants" ]]; then
    valid_variants=$(cat /usr/share/X11/xkb/rules/xorg.lst | sed -n '/^! variant/,/^$/p' | awk 'NR > 1 {print $1}')
    IFS=',' read -r -a variant_array <<< "$variants"
    for variant in "${variant_array[@]}"; do
        if ! echo "$valid_variants" | grep -q -w "$variant"; then
            echo "ERROR: Invalid variant: $variant"
            exit 1
        fi
    done
    sed -i -E "s/XKBVARIANT=\".*\"/XKBVARIANT=\"$variants\"/" /etc/default/keyboard
    echo "INFO: Set variants to $variants"
fi

if [[ -n "$options" ]]; then
    valid_options=$(cat /usr/share/X11/xkb/rules/xorg.lst | sed -n '/^! option/,/^$/p' | awk 'NR > 1 {print $1}')
    IFS=',' read -r -a option_array <<< "$options"
    for option in "${option_array[@]}"; do
        if ! echo "$valid_options" | grep -q -w "$option"; then
            echo "ERROR: Invalid option: $option"
            exit 1
        fi
    done
    sed -i -E "s/XKBOPTIONS=\".*\"/XKBOPTIONS=\"$options\"/" /etc/default/keyboard
    echo "INFO: Set options to $options"
fi

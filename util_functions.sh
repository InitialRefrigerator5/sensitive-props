#!/system/bin/busybox sh

# Function that normalizes a boolean value and returns 0, 1, or a string
# Usage: boolval "value"
boolval() {
    case "$(printf "%s" "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1 | true | on | enabled) return 0 ;;    # Truely
    0 | false | off | disabled) return 1 ;; # Falsely
    *) return 1 ;;                          # Everything else - return a string
    esac
}

# Enhanced boolval function to only identify booleans
is_bool() {
    case "$(printf "%s" "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1 | true | on | enabled | 0 | false | off | disabled) return 0 ;; # True (is a boolean)
    *) return 1 ;;                                                    # False (not a boolean)
    esac
}

# Function to print a message to the user interface.
ui_print() { echo "$1"; }

# Function to abort the script with an error message.
abort() {
    message="$1"
    remove_module="${2:-true}"

    ui_print " [!] $message"

    # Remove module on next reboot if requested
    if boolval "$remove_module"; then
        touch "$MODPATH/remove"
        ui_print " ! The module will be removed on next reboot !"
        ui_print ""
        sleep 5
        exit 1
    fi

    sleep 5
    return 1
}

set_permissions() { # Handle permissions without errors
    [ -e "$1" ] && chmod "$2" "$1" &>/dev/null
}

# Function to construct arguments for resetprop based on prop name
_build_resetprop_args() {
    prop_name="$1"
    shift

    case "$prop_name" in
    persist.*) set -- -p -v "$prop_name" ;; # Use persist mode
    *) set -- -n -v "$prop_name" ;;         # Use normal mode
    esac
    echo "$@"
}

exist_resetprop() { # Reset a property if it exists
    getprop "$1" | grep -q '.' && resetprop $(_build_resetprop_args "$1") ""
}

check_resetprop() { # Reset a property if it exists and doesn't match the desired value
    VALUE="$(resetprop -v "$1")"
    [ ! -z "$VALUE" ] && [ "$VALUE" != "$2" ] && resetprop $(_build_resetprop_args "$1") "$2"
}

maybe_resetprop() { # Reset a property if it exists and matches a pattern
    VALUE="$(resetprop -v "$1")"
    [ ! -z "$VALUE" ] && echo "$VALUE" | grep -q "$2" && resetprop $(_build_resetprop_args "$1") "$3"
}

replace_value_resetprop() { # Replace a substring in a property's value
    VALUE="$(resetprop -v "$1")"
    [ -z "$VALUE" ] && return
    VALUE_NEW="$(echo -n "$VALUE" | sed "s|${2}|${3}|g")"
    [ "$VALUE" == "$VALUE_NEW" ] || resetprop $(_build_resetprop_args "$1") "$VALUE_NEW"
}

deleteprop() {
    for search_string in "$@"; do
        # Find all property names containing the search string
        getprop | cut -d'[' -f2 | cut -d']' -f1 | grep -- "$search_string" | while read -r prop_name; do
            if [ -z "$prop_name" ]; then continue; fi

            resetprop -p --delete "$prop_name" >/dev/null 2>&1

            # Verify that the property is now empty
            if [ -z "$(getprop "$prop_name")" ]; then
                ui_print "   ? Verified: $prop_name is gone."
            else
                ui_print "   ! Verification failed: $prop_name still exists."
            fi
        done
    done
}

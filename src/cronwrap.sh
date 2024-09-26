#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

# based on this python script cronwrap.py
# https://github.com/Doist/cronwrap/blob/master/scripts/cronwrap

# cronwrap
# ~~~~~~~~~~~~~~
# A cron job wrapper that wraps jobs and enables better error reporting and command timeouts.

# Usage:
# $ cronwrap -c "sleep 2" -t "1s" -e cron@my_domain.com
# $ cronwrap -c "blah" -t "1s" -e cron@my_domain.com
# $ cronwrap -c "ls" -e cron@my_domain.com
# $ cronwrap -c "ls" -e cron@my_domain.com -v

# --- Functions ---
send_email() {
    local email="$1"
    local subject="$2"
    local message="$3"
    local verbose="$4"

    echo "$message" | mail -s "$subject" "$email"
    if [[ "$verbose" == true ]]; then
        echo "Sent an email to $email"
    fi
}

render_email_template() {
    local title="$1"
    local cmd="$2"
    local start_time="$3"
    local end_time="$4"
    local run_time="$5"
    local timeout="$6"
    local return_code="$7"
    local stdout="$8"
    local stderr="$9"

    cat <<EOF
*$title*

*Command:*
\`\`\`
$cmd
\`\`\`

*COMMAND STARTED:*
$start_time

*COMMAND FINISHED:*
$end_time

*COMMAND RAN FOR:*
$run_time seconds

*COMMAND'S TIMEOUT IS SET AT:*
$timeout

*RETURN CODE WAS:*
\`$return_code\`

*ERROR OUTPUT:*
\`\`\`
$stderr
\`\`\`

*STANDARD OUTPUT:*
\`\`\`
$stdout
\`\`\`
EOF
}

run_command() {
    local command="$1"
    local max_time="$2"
    local stdout_path="$3"
    local stderr_path="$4"

    local start
    start=$(date +%s)

    # Execute the command, redirect stdout and stderr to temp files
    eval "$command" >"$stdout_path" 2>"$stderr_path"
    local return_code=$?

    local end
    end=$(date +%s)
    run_time=$((end - start))

    # Check timeout
    local max_seconds
    max_seconds=$(convert_to_seconds "$max_time")
    if [[ "$run_time" -gt "$max_seconds" ]]; then
        return 124 # Timeout error code
    fi

    return "$return_code"
}

convert_to_seconds() {
    local time_str="$1"
    local num
    num=$(echo "$time_str" | grep -o -E '[0-9]+')
    local unit
    unit=$(echo "$time_str" | grep -o -E '[a-zA-Z]+')

    case "$unit" in
    h) echo $((num * 3600)) ;;
    m) echo $((num * 60)) ;;
    s) echo $((num)) ;;
    *) echo 0 ;;
    esac
}

cleanup() {
    # Clean up temporary files
    rm -f "$stdout_log_file_path" "$stderr_log_file_path"
}

# --- Main Logic ---
verbose=false
emails=""
cmd=""
max_time="1h"

while getopts ":c:e:t:v" opt; do
    case $opt in
    c) cmd="$OPTARG" ;;
    e) emails="$OPTARG" ;;
    t) max_time="$OPTARG" ;;
    v) verbose=true ;;
    *)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done

if [[ -z "$cmd" ]]; then
    echo "No command provided. Use -c to specify a command."
    exit 1
fi

# Create temporary files for stdout and stderr
stdout_log_file_path=$(mktemp)
stderr_log_file_path=$(mktemp)
trap cleanup EXIT INT TERM # Ensure cleanup happens when the script exits

start_time=$(date --iso-8601=seconds)
run_time=""

# Temporarily disable 'errexit' to capture command return code manually
set +o errexit
# Run the command and capture output
run_command "$cmd" "$max_time" "$stdout_log_file_path" "$stderr_log_file_path"
return_code=$?
set -o errexit # Re-enable 'errexit' after capturing return code
stdout=$(<"$stdout_log_file_path")
stderr=$(<"$stderr_log_file_path")

end_time=$(date --iso-8601=seconds)

if [[ "$return_code" -eq 0 ]]; then
    result_str=$(render_email_template "CRONWRAP RAN COMMAND SUCCESSFULLY:" "$cmd" "$start_time" "$end_time" "$run_time" "$max_time" "$return_code" "$stdout" "$stderr")
    if [[ "$verbose" == true ]]; then
        if [[ -n "$emails" ]]; then
            for email in ${emails//,/ }; do
                send_email "$email" "Host $(hostname): cronwrap ran command successfully!" "$result_str" "$verbose"
            done
        else
            echo "$result_str"
        fi
    fi
elif [[ "$return_code" -eq 124 ]]; then
    result_str=$(render_email_template "CRONWRAP DETECTED A TIMEOUT ON FOLLOWING COMMAND:" "$cmd" "$start_time" "$end_time" "$run_time" "$max_time" "$return_code" "$stdout" "$stderr")
    if [[ -n "$emails" ]]; then
        for email in ${emails//,/ }; do
            send_email "$email" "Host $(hostname): cronwrap detected a timeout!" "$result_str" "$verbose"
        done
    else
        echo "$result_str"
    fi
else
    result_str=$(render_email_template "CRONWRAP DETECTED FAILURE OR ERROR OUTPUT FOR THE COMMAND:" "$cmd" "$start_time" "$end_time" "$run_time" "$max_time" "$return_code" "$stdout" "$stderr")
    if [[ -n "$emails" ]]; then
        for email in ${emails//,/ }; do
            send_email "$email" "Host $(hostname): cronwrap detected a failure!" "$result_str" "$verbose"
        done
    else
        echo "$result_str"
    fi
    exit 1
fi

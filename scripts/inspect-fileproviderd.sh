#!/bin/bash

set -u

process_name="fileproviderd"
log_minutes=15
trace_seconds=10
trace=0

usage() {
    cat <<'EOF'
Usage: inspect-fileproviderd.sh [options]

Options:
  -p, --process NAME   Process name to inspect (default: fileproviderd)
  -m, --minutes N      Minutes of recent logs to show (default: 15)
  -s, --seconds N      Seconds for live fs_usage tracing (default: 10)
      --trace          Run a live fs_usage sample with sudo
  -h, --help           Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--process)
            process_name="${2:-}"
            shift 2
            ;;
        -m|--minutes)
            log_minutes="${2:-}"
            shift 2
            ;;
        -s|--seconds)
            trace_seconds="${2:-}"
            shift 2
            ;;
        --trace)
            trace=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$process_name" ]; then
    echo "Process name cannot be empty."
    exit 1
fi

filter_re='OneDrive|Google Drive|CloudDocs|iCloud|fileproviderd|mds_stores|Spotlight|reconcil|index|download|sync|fetch-content|itemChanged|update-item|create-item|itemPropagationStatusChanged'

echo "=== Snapshot ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Process: $process_name"
echo "Log window: last ${log_minutes}m"
echo "Trace sample: ${trace_seconds}s"
echo

pids="$(pgrep -x "$process_name" || true)"
if [ -n "$pids" ]; then
    pid_list="$(printf '%s\n' "$pids" | paste -sd, -)"
    echo "=== ps ==="
    ps -p "$pid_list" -o pid,ppid,user,%cpu,%mem,etime,command
    echo

    echo "=== open files of $process_name ==="
    for pid in $pids; do
        echo "--- pid $pid ---"
        lsof -nP -p "$pid" 2>/dev/null | rg 'CloudStorage|Mobile Documents|OneDrive|Google Drive|iCloud|CloudDocs|fileprovider|mds|Spotlight|codex|vscode' || true
        echo
    done
else
    echo "No running process named '$process_name' found."
    echo
fi

if command -v fileproviderctl >/dev/null 2>&1; then
    echo "=== fileproviderctl summary ==="
    for domain in \
        com.apple.CloudDocs.iCloudDriveFileProvider \
        com.microsoft.OneDrive-mac.FileProvider \
        com.google.drivefs.fpext
    do
        echo "--- $domain ---"
        fileproviderctl dump "$domain" 2>/dev/null | rg -n 'display name|bundle URL|scheduler:|pending-indexable-count|total-indexable-count|scheduling state|error generation|active enumerators|download scheduler|reconciliation|missingLastKnownVersion|Excluded From Sync Due To Filename|create-item|update-item|itemPropagationStatusChanged|itemChangedRemotely|itemUpdatedInFPSnapshot|batch-indexed' || true
        echo
    done
else
    echo "fileproviderctl not found."
    echo
fi

echo "=== recent logs ==="
log show --style compact --last "${log_minutes}m" --predicate '(process == "fileproviderd" OR process == "mds_stores") AND (eventMessage CONTAINS[c] "OneDrive" OR eventMessage CONTAINS[c] "Google Drive" OR eventMessage CONTAINS[c] "CloudDocs" OR eventMessage CONTAINS[c] "iCloud")' --info --debug 2>/dev/null | tail -n 200 || true
echo

if [ "$trace" -eq 1 ]; then
    echo "=== live fs_usage ==="
    if command -v sudo >/dev/null 2>&1; then
        sudo fs_usage -w -f filesys -t "$trace_seconds" "$process_name" 2>/dev/null | rg "$filter_re" || true
    else
        fs_usage -w -f filesys -t "$trace_seconds" "$process_name" 2>/dev/null | rg "$filter_re" || true
    fi
fi

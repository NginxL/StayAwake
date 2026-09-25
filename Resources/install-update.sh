#!/bin/bash
set -euo pipefail
owner_pid="$1"
pending="$2"
destination="$3"
workspace="$4"
parent="$(dirname "$destination")"
backup="$parent/.StayAwake-previous.app"

for ((attempt=0; attempt<100; attempt++)); do
    if ! kill -0 "$owner_pid" 2>/dev/null; then break; fi
    sleep 0.2
done
if kill -0 "$owner_pid" 2>/dev/null; then
    printf 'App did not exit; update not installed.\n' >&2
    exit 1
fi

# Only the prior update backup is replaced. Keep a recoverable copy of the last installed app.
if [[ -e "$backup" ]]; then
    mv "$backup" "$workspace/older-backup.app"
fi
if ! mv "$destination" "$backup"; then
    printf 'Could not preserve the installed app.\n' >&2
    exit 1
fi
if ! mv "$pending" "$destination"; then
    mv "$backup" "$destination"
    /usr/bin/open "$destination"
    printf 'Update failed; restored the previous app.\n' >&2
    exit 1
fi
if ! /usr/bin/open "$destination"; then
    mv "$destination" "$workspace/failed-update.app"
    mv "$backup" "$destination"
    /usr/bin/open "$destination"
    printf 'Launch failed; restored the previous app.\n' >&2
    exit 1
fi
printf 'Update installed. Previous version: %s\n' "$backup"

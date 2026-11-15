#!/bin/sh
# Rewrite a Slack permalink into the web client's thread URL, so the Slack PWA opens it without the desktop-app handoff page.
url=$1
start=""
for app in "$HOME/Applications/Chromium Apps.localized"/*.app; do
  s=$(/usr/libexec/PlistBuddy -c 'Print :CrAppModeShortcutURL' "$app/Contents/Info.plist" 2>/dev/null)
  case $s in https://app.slack.com/client/*) start=$s && break ;; esac
done
team=$(printf '%s' "$start" | cut -d/ -f5)
channel=$(printf '%s' "$url" | sed -nE 's#^https://[^/]+/archives/([A-Z0-9]+)/p([0-9]{16}).*#\1#p')
packed=$(printf '%s' "$url" | sed -nE 's#^https://[^/]+/archives/([A-Z0-9]+)/p([0-9]{16}).*#\2#p')
if [ -z "$team" ] || [ -z "$channel" ] || [ -z "$packed" ]; then
  printf '%s\n' "$url"
  exit 0
fi
ts="$(printf '%s' "$packed" | cut -c1-10).$(printf '%s' "$packed" | cut -c11-16)"
root=$(printf '%s' "$url" | sed -nE 's#.*[?&]thread_ts=([0-9]+\.[0-9]+).*#\1#p')
printf 'https://app.slack.com/client/%s/%s/thread/%s-%s\n' "$team" "$channel" "$channel" "${root:-$ts}"

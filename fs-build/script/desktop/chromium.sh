#!/bin/bash
set -e

chmod 666 -R  chromium/
mv chromium/initial_bookmarks.html /usr/share/chromium/
mv chromium/master_preferences /etc/chromium/

rm -r chromium/
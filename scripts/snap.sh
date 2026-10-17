#!/bin/sh
# Debug helper: asks a running Debug build of Blink to write PNGs of its windows.
osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("BlinkWriteSnapshots", $(), $(), true)' >/dev/null

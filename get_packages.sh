#!/bin/bash
# This script generates a list of packages currently installed on a system, in a format conducive to
# automagically installing on a new system at system install time via autoinstall.

apt list --installed | sed -E '1d;{s|/.*| |; h; x; s/(.*)/  - \1/}' > installed.list 

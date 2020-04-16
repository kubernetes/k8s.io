#!/usr/bin/env bash
#
# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generic utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

function _color() {
    tput setf "$1" || true
}

function _nocolor() {
    tput sgr0 || true
}

# Print the arguments in a given color
# $1: The color code (numeric, see `tput setf`)
# $2+: The things to print
function color() {
    _color "$1"
    shift
    echo "$@"
    _nocolor
}

# Indent each line of stdin.
# example: <command> | indent
function indent() {
    # Simple 'sed' messes up end-of-line when mixed with color codes,
    # and I could not figure out why.
    IFS=''
    while read X; do echo "  ${X}"; done
}

#!/bin/bash

#source "bash-guard.sh"
#__bash_include_guard || return   # 1 => hoppar över (redan laddad/oförändrad)

source "$(dirname "${BASH_SOURCE[0]}")/bash-filecache-guard.sh" || return
__bash_filecache_guard || return

source "test1.sh"

echo "test 2 - hello"

#__bash_guard_end

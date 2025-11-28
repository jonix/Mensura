#/bin/bash

source "bash-guard-filecache-inmmem.sh"
__bash_include_guard || return   # 1 => hoppar över (redan laddad/oförändrad)

echo "hello"
__bash_include_guard_end

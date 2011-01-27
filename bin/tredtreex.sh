#!/bin/bash

# temporary script for running TrEd on treex files using the new extension

# can't use runtred, as it runs setup_platform and thus destroys PERLLIBS
/f/common/exec/tred -O PreInstalledExtensionsDir=/net/os/h/zabokrtsky/tectomt/devel/treex/lib/Treex/Core/share/tred_extension "$@"


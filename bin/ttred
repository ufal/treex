#!/bin/bash

# temporary script for running TrEd on treex files using the new extension

# can't use runtred, as it runs setup_platform and thus destroys PERLLIBS

echo "Running TrEd customized for Treex"

TRED_RUNNER=`perl -e 'use Treex::Core::Config; print Treex::Core::Config::tred_dir."/tred\n"'`

EXTENSION_DIR=`perl -e 'use Treex::Core::Config; print Treex::Core::Config::tred_extension_dir."\n"'`

$TRED_RUNNER -O PreInstalledExtensionsDir=$EXTENSION_DIR "$@"


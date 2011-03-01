#!/bin/bash

#   ../lib/Treex/Block/Read/t/*t

for SCRIPT in \
   ../lib/Treex/Core/t/*.t
  do
    echo
    echo RUNNING $SCRIPT
    echo
    ./$SCRIPT
  done

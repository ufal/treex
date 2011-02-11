#!/bin/bash

for SCRIPT in \
   ../lib/Treex/Core/t/*.t \
   ../lib/Treex/Block/Read/t/*t
  do
    echo
    echo RUNNING $SCRIPT
    echo
    ./$SCRIPT
  done

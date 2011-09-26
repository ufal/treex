package Treex::Block::A2A::Transform::Coord_fPhRsHcHpB;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::CoordStyle';

has '+family' => ( default => 'Prague');
has '+head' => ( default => 'right');
has '+shared' => ( default => 'head');
has '+conjunction' => ( default => 'head');
has '+punctuation' => ( default => 'between');

1;

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::A2A::Transform::Coord_fMhLsNcBpP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::CoordStyle';

has '+family' => ( default => 'Moscow');
has '+head' => ( default => 'left');
has '+shared' => ( default => 'nearest');
has '+conjunction' => ( default => 'between');
has '+punctuation' => ( default => 'previous');

1;

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

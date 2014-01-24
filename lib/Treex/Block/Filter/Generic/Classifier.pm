package Treex::Block::Filter::Generic::Classifier;
use Moose::Role;

requires qw( init see learn save load predict score );

1;

=over

=item Treex::Block::Filter::Generic::Classifier

A role that must be implemented by specific classifier types.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

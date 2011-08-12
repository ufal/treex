package Treex::Block::Test::A::NonemptyAttr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    foreach my $attr_name (qw(form lemma tag)) {
        if ( $anode->get_attr($attr_name) eq '' ) {
            $self->complain($anode, $attr_name);
        }
    }
}

1;

=over

=item Treex::Block::Test::A::NonemptyAttr

Attributes form, lemma, and tag must be filled with non-empty value.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


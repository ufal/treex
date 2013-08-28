package Treex::Block::HamleDT::Test::NonemptyAttr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    foreach my $attr_name (qw(form lemma tag)) {
        my $attr_value = $anode->get_attr($attr_name);
        if ( !defined $attr_value || $attr_value eq '' ) {
            $self->complain($anode, $attr_name);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::NonemptyAttr

Report attributes form, lemma, or tag with empty string or undefined value.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


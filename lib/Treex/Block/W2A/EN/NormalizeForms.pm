package Treex::Block::W2A::EN::NormalizeForms;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

sub process_anode {
    my ( $self, $anode ) = @_;

    my $form = $anode->form;

    if ( $form eq '"' ) {
        my $previous_anode = $anode->get_prev_node();
        $form = '``' if ( !$previous_anode || $previous_anode->form =~ /^[\(\[{<]$/ || !$previous_anode->no_space_after );
    }

    $form =~ s/’/'/g;
    $form =~ s/"/''/g;
    $form =~ s/“/``/g;
    $form =~ s/”/''/g;
    $form =~ s/«/``/g;
    $form =~ s/»/''/g;
    $form =~ s/—/--/g;

    $anode->set_form($form);

    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::EN::NormalizeForms

Some forms are normalized, for example all the quotation marks
get the normalized form `` or ''.

=back

=cut

# Copyright 2010-2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

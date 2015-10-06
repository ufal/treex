package Treex::Block::W2A::EN::NormalizeForms;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    my $form = $anode->form;

    if ( $form eq '"' ) {
        my $previous_anode = $anode->get_prev_node();
        if ( !$previous_anode || $previous_anode->form =~ /^[\(\[{<]$/ || !$previous_anode->no_space_after ) {
            $form = '``';
        }
    }

    $form =~ s/[’´]/'/g;
    $form =~ s/["”»]/''/g;
    $form =~ s/[“«]/``/g;
    $form =~ s/—/--/g;

    $anode->set_form($form);

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::NormalizeForms - normalize some wordforms

=head1 DESCRIPTION

Some forms are normalized, for example all the quotation marks
get the normalized form `` or ''.

=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_anode

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


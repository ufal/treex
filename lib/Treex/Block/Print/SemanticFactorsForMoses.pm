package Treex::Block::Print::SemanticFactorsForMoses;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.txt' );

sub process_atree {

    my ( $self, $aroot ) = @_;
    my @data = ();

    foreach my $anode ( $aroot->get_descendants( { ordered => 1 } ) ) {
        my $form = $anode->form // '';
        my ( $valframe, $functor ) = ( '', '' );
        my ($tnode) = $anode->get_referencing_nodes('a/lex.rf');
        if ($tnode) {
            $valframe = $tnode->val_frame_rf // '';
            $functor  = $tnode->functor      // '';
        }

        my $tok = (
            $form . '|'
                . ( $valframe ne '' ? $valframe : $functor ) . '|'
                . ( $valframe ne '' ? $functor  : '' )
        );
        $tok =~ s/ /_/g;
        push @data, $tok;
    }
    my $sent_id = $aroot->id;
    $sent_id =~ s/^a_tree-..-//;
    $sent_id =~ s/-root$//;


    print { $self->_file_handle } $sent_id, "\t", join( " ", @data ), "\n";

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::SemanticFactorsForMoses

=head1 DESCRIPTION


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

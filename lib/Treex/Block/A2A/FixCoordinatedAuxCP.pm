package Treex::Block::A2A::FixCoordinatedAuxCP;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {

    my ( $self, $anode ) = @_;

    return if ( !$anode->is_coap_root );

    my $aux_above = undef;
    $aux_above = $anode->get_parent if ( ( $anode->get_parent->afun || '' ) =~ /Aux[CP]/ );

    my @members = grep { $_->is_member } $anode->get_children( { ordered => 1 } );
    my @aux_under = grep { ( $_->afun || '' ) =~ /Aux[CP]/ } $anode->get_children( { ordered => 1 } );

    # Fix loose prepositions by attaching them to following siblings
    foreach my $loose_prep ( grep { $_->is_leaf } @aux_under ) {
        log_warn( 'Loose preposition: ' . $loose_prep->get_address() );
        my ($following_sibling) = $loose_prep->get_siblings( { following_only => 1 } );

        $following_sibling->set_parent($loose_prep);
        $loose_prep->set_is_member( $following_sibling->is_member );
        $following_sibling->set_is_member(0);

        # update the lists
        @members = grep { $_ != $following_sibling && ( $loose_prep->is_member || $_ != $loose_prep ) } @members;
        @aux_under = grep { ( $_->afun || '' ) =~ /Aux[CP]/ } $anode->get_children( { ordered => 1 } );
    }

    # Rehang preposition nodes from above the coordination if there are preposition nodes above and under
    if ( $aux_above && @aux_under ) {
        log_warn( 'AuxCP above and under: ' . $anode->get_address() );

        $anode->set_parent( $aux_above->get_parent );
        $aux_above->set_parent($anode);
        $members[0]->set_parent($aux_above);

        $anode->set_is_member( $aux_above->is_member );
        $aux_above->set_is_member(1);
        $members[0]->set_is_member(0);
    }

    # Rehang preposition nodes from below the coordination if the formemes are the same and there are missing forms
    elsif ( !$aux_above && @aux_under && @aux_under < @members ) {
        
        log_warn( 'Shared AuxCP below ?: ' . $anode->get_address() );
# TODO this probably does not work well
#        my @formemes = map {
#            my ($t) = (
#                $_->get_referencing_nodes('a/lex.rf'),
#                $_->get_referencing_nodes('a/aux.rf')
#            );
#            return $t->formeme
#        } @members;
#        
#        if ( all { $_ eq $formemes[0] } @formemes ) {
#            
#        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::FixCoordinatedAuxCP

=head1 DESCRIPTION

This block is special for generating correct a-trees given t-trees and surface. 
It tries to fix generated coordinated auxiliaries that do not correspond to the sentence surface
(rehang them correctly).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

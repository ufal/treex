package Treex::Block::A2N::CS::FixNERforIT;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # must be an unknown lemma
    return if ( !$anode->wild->{lemma_guessed} );
    
    # require uppercase letter in the middle of the sentence
    return if ( $anode->form !~ /\p{Lu}/ or $anode->ord == 1 );

    # skip those that already have an n-node
    return if ( $anode->n_node() );
    
    my $ntree = $anode->get_zone->get_ntree();
    my $nnode = $ntree->create_child({
        ne_type => 'o_',
        normalized_name => $anode->lemma,
    });
    $nnode->set_anodes($anode);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2N::CS::FixNERforIT

=head1 DESCRIPTION

Setting things with uppercase letters that are not in MorphoDiTa's dictionary
as NEs of type "artefact".

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

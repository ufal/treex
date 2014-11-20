package Treex::Block::T2A::NL::FixMultiwordSurnames;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    return if ( ($tnode->formeme // '') !~ /^n/ ); # TODO check named entity somehow
    
    my ( $prefixes, $surname ) = ( ( $tnode->t_lemma || '' ) =~ /^((?:van|de|den|von|het)(?:_(?:van|de|den|von|het))*)_([^_]*)$/ );

    # only for names with some prefixes
    return if ( !$prefixes );
    my $anode = $tnode->get_lex_anode() or return;
        
    # remove prefix from the verbal node
    $anode->set_lemma($surname);

    # create the prefix nodes
    foreach my $prefix (reverse split /_/, $prefixes){
    
        my $prefix_anode = $anode->create_child(
            {
                'lemma'        => $prefix,
                'form'         => $prefix,
                'afun'         => 'AuxP',
                'morphcat/pos' => '!',
            }
        );
        $prefix_anode->iset->add( 'pos' => 'adp', 'adpostype' => 'prep' );
        $prefix_anode->shift_before_node($anode);        
        $tnode->add_aux_anodes($prefix_anode);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::FixMultiwordSurnames

=head1 DESCRIPTION

Add separate prefix nodes for multi-word surnames ('Van Gogh' etc.).

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

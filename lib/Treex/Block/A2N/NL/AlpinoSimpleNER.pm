package Treex::Block::A2N::NL::AlpinoSimpleNER;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

extends 'Treex::Core::Block';

# Alpino-to-Treex named entity types conversion 
Readonly my $NE_TYPES => {

    'ORG'  => 'i_',    # organizations
    'LOC'  => 'g_',    # locations
    'PER'  => 'p_',    # personal names
    'MISC' => 'o_',    # miscellaneous (tagged as "artifacts" in Treex)
    'year' => 'ty',    # year
};


sub process_zone {

    my ( $self, $zone ) = @_;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    # skip empty sentence
    return if !@anodes;

    # Create new n-tree
    my $nroot = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    my @abuf    = ();
    my $neclass = '';

    # Add all named entities found to the n-tree
    foreach my $anode (@anodes) {

        if ( @abuf and ( !$anode->wild->{neclass} or ( $anode->wild->{neclass} ne $neclass ) ) ) {
            $self->create_nnode( $nroot, $neclass, \@abuf );
            @abuf    = ();
            $neclass = '';
        }
        if ( $anode->wild->{neclass} ) {
            $neclass = $anode->wild->{neclass};
            push @abuf, $anode;
        }
    }
    if ($neclass) {
        $self->create_nnode( $nroot, $neclass, \@abuf );
    }

    return;
}


sub create_nnode {
    my ( $self, $nroot, $neclass, $anodes ) = @_;
    my $nnode = $nroot->create_child(
        {
            ne_type => $NE_TYPES->{$neclass},
            normalized_name => join( ' ', map { $_->lemma } @$anodes ),
        }
    );
    if ( !$NE_TYPES->{$neclass} ) {
        log_warn( 'Unknown Alpino NE type: ' . $neclass . ' / ' . $nnode->id . ' ' . $nnode->normalized_name );
    }
    $nnode->set_anodes(@$anodes);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::NL::AlpinoSimpleNER

=head1 DESCRIPTION

A trivial NER for Dutch, using the information previously provided by the Alpino
parser (the "neclass" attribute) to build n-trees.

It won't do anything unless the "neclass" attribute is set in a-nodes.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

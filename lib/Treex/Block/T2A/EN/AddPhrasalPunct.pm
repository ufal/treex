package Treex::Block::T2A::EN::AddPhrasalPunct;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    return if ( !$tnode->is_clause_head() );

    my (@tphrases) = $tnode->get_echildren( { following_only => 1 } );
    my $first_tphrase = shift @tphrases;

    foreach my $tphrase (@tphrases) {

        # "..., arguing that ..."
        if ( $tphrase->formeme =~ /v:ger/ and any { $_->formeme =~ /v:that\+fin/ } $tphrase->get_echildren() ) {
            _create_comma($tphrase);
        }

        # TODO further rules (n:with+X, n:accord_to+X...)?
    }

    return;
}

sub _create_comma {
    my ($tparent) = @_;
    my $aparent = $tparent->get_lex_anode();
    return if ( !$aparent );

    my $aprev = $aparent->get_prev_node();
    my $anext = $aparent->get_descendants( { add_self => 1, first_only => 1 } );
    return if ( !$aprev or $aprev->lemma =~ /([.;:-]|''|``)/ or !$anext or $anext->lemma =~ /([.;:-]|''|``)/ );

    # create a comma, hang it under the main verb
    my $comma = $aparent->create_child(
        {   'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
    $comma->shift_before_subtree($aparent);
    $tparent->add_aux_anodes($comma);
    return $comma;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddPhrasalPunct

=head1 DESCRIPTION

Adding punctuation for various phrases towards the end of the sentence where it usually occurs.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

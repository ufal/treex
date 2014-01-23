package Treex::Block::T2A::EN::AddPossessiveMarkers;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();

    # select only possessive nouns
    if ( ( $tnode->gram_sempos // '' ) !~ /^n/ or $tnode->formeme ne 'n:poss' or $tnode->t_lemma eq '#PersPron' ) {
        return;
    }
    my $form = '\'s';
    if ( $anode->lemma =~ /[xs]$/ or $anode->morphcat_number eq 'P' ) {
        $form = '\'';
    }

    my $possnode = $anode->create_child(
        {
            'morphcat/pos'  => '!',
            'conll/pos'     => 'POS',
            'lemma'         => $form,
            'form'          => $form,
            'clause_number' => $anode->clause_number,
        }
    );

    $possnode->shift_after_node($anode);
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::AddPossessiveMarkers

=head1 DESCRIPTION

New a-nodes are added for possessive markers ("'s" or "'") and hanged under the a-node of
the corresponding noun.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

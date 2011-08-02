package Treex::Block::T2A::CS::FixPossessiveAdjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS;

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if (( $t_node->formeme || "" ) eq 'n:poss'
        and ( $t_node->get_attr('mlayer_pos') || "" ) ne 'P'
        and ( $t_node->t_lemma || "" ) ne '#PersPron'
        )
    {

        my $a_node     = $t_node->get_lex_anode();    # or return;
        my $noun_lemma = $a_node->lemma;

        #            print "noun: $noun_lemma\n";

        my $adj_lemma = Treex::Tool::Lexicon::CS::get_poss_adj($noun_lemma);

        # convert to adjective only if the corresponding adjective actually exists
        if ($adj_lemma) {
            $a_node->set_lemma($adj_lemma);
            $a_node->set_attr( 'morphcat/subpos', '.' );
            $a_node->set_attr( 'morphcat/pos',    'A' );

            # with adjectives, the following categories should come from agreement
            foreach my $cat (qw(gender number)) {
                $a_node->set_attr( "morphcat/$cat", '.' );
            }
        }
        # if the adjective doesn't exist, fall back to noun in genitive
        else {
            $t_node->set_formeme('n:2');
            $a_node->set_attr( 'morphcat/case', '2' );
        }

        #            print "$noun_lemma ==> $adj_lemma\n";
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::FixPossessiveAdjs

=head1 DESCRIPTION

Nouns with the 'n:poss' formeme are turned to possessive adjectives on the a-layer. 
If the corresponding adjectival form is not found to exist, the formeme is replaced 
with 'n:2'.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

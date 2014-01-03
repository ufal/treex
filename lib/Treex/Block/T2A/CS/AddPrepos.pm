package Treex::Block::T2A::CS::AddPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddPrepos';

override 'postprocess' => sub {

    my ( $self, $tnode, $anode, $prep_forms_string, $prep_nodes ) = @_;

    # moving leading adverbs in front of the prepositional group ('v zejmena USA' --> 'zejmena v USA')
    # but keeping some adverbs that relate to numerals ('na téměř XXX milionů dolarů' etc.)
    my $t_first = $tnode->get_children( { preceding_only => 1, first_only => 1 } );

    if ($tnode->formeme =~ /^n/
        && defined $t_first
        && ( $t_first->functor eq 'RHEM' || $t_first->formeme =~ /^adv/ )
        && $t_first->get_lex_anode
        && !( $prep_forms_string eq 'na' && $t_first->t_lemma =~ /^(téměř|kolem|okolo|zhruba)$/ )
        )
    {
        $t_first->get_lex_anode->shift_before_node( $prep_nodes->[0] );
    }

    return;

};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::AddPrepos

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.

Czech-specific: moving some adverbs in front of whole prepositional groups. 

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

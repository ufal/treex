package Treex::Block::T2A::CS::MarkLexVerbChildren;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

extends 'Treex::Core::Block';

Readonly my $PDT_VALLEX => 'vallex.xml';
Readonly my $LANG       => 'cs';

# Functors of t-nodes whose a-nodes typically hang on the lexical verb, not the modal / auxiliary 
Readonly my $TYP_FUNCTORS => 'ACT|PAT|ADDR|ORIG|EFF|BEN|MEANS|DIR1|DIR2|DIR3|DIFF|
EXT|INTT|MANN|RESL|SUBS|TFHL|THO|ACMP|AIM|DPHR|CPHR';
 
sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();

    return if ( !$anode || $tnode->is_coap_root || $tnode->is_root );

    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
    my $aparent = $tparent->get_lex_anode();
    my $sempos = $tparent->gram_sempos || '';

    return if ( !$aparent || $sempos ne 'v' );

    if (( $anode->afun || '' ) eq 'Sb'){ # exclude subjects 
        return;
    }
    if ( $tnode->functor =~ m/^($TYP_FUNCTORS)$/sxm ){ # use functors list
        $anode->wild->{lex_verb_child} = 1;
        return;
    }

    # for other functors, use valency dictionary
    my @frames = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma( $PDT_VALLEX, $LANG, $aparent->lemma, $sempos );
    foreach my $frame (@frames) {
        if ( $frame->functor( $tnode->functor ) ) {
            $anode->wild->{lex_verb_child} = 1;
            return;
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::MarkLexVerbChildren

=head1 DESCRIPTION

This block marks all a-layer children of verbal nodes which should be hanged under the lexical part of a compound
predicate, not the auxiliary or modal verb. The marking is preserved in a L<wild|Treex::Core::WildAttr> attribute.

The marking proceeds as follows:

=over

=item *

All subjects are excluded (since they should always hang on the conjugated verb, which is the auxiliary / modal).

=item *

All a-nodes nodes corresponding to t-nodes with the following functors are marked: ACT, PAT, ADDR, ORIG, 
EFF, BEN, MEANS, DIR1, DIR2, DIR3, DIFF, EXT, INTT, MANN, RESL, SUBS, TFHL, THO, ACMP, AIM, DPHR, CPHR.
This list of functors is based on a manual inquiry of a few cases for each functor in PDT 2.0.

=item * 

All children bound to their parents by valency (based on PDT-Vallex valency dictionary) are marked.

=back

=head1 TODO

This should probably be solved by some form of machine learning, since the instructions in the PDT annotation
manual are really unclear and the data itself do not show any simple rule. This resolution in PDT is most probably 
based also on word order and projectivity.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

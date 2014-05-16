package Treex::Block::A2T::EN::SetFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %tag2functor = (
    "CC"    => "CONJ",    # coordinating conjunction
    "CD"    => "RSTR",    # cardinal number
    "JJ"    => "RSTR",    # adjective
    "JJR"   => "RSTR",    # adjective, comparative
    "JJS"   => "RSTR",    # adjective, superlative
    "PRP\$" => "APP",     # possessive pronoun
    "RB"    => "MANN",    # adverb
    "RBR"   => "CPR",     # adverb comparative
    "RBS"   => "MANN",    # adverb superlative
);

#my %tag2functor=( # prop. bank functional tags => functors
#                "SBJ" => "ACT", # surface subject
#                "BNF" => "BEN", # benefactive
#                "DTV" => "ADDR", # dative
#                "EXT" => "EXT", # extent
#                "LGS" => "ACT", # logical subject
#                "LOC" => "LOC", # location
#                "MNR" => "MANN", # manner
#                "PRP" => "CAUS", # purpose or reason
#                "TMP" => "TWHEN", # temporal adverbial
#                "PRD" => "PAT" # temporal adverbial
#               );

my %aux2functor = (
    "by"      => "MEANS",
    "than"    => "CPR",
    "with"    => "ACMP",
    "of"      => "APP",
    "if"      => "COND",
    "into"    => "DIR3",
    "because" => "CAUS",
    "in"      => "LOC",
    "since"   => "TSIN",
    "until"   => "TTILL",
    "accord"  => "REG",
    "despite" => "CNCS",
    "like"    => "CPR",
    "for"     => "BEN",
    "under"   => "LOC",
    "on"      => "LOC",
    "above"   => "LOC",
    "below"   => "LOC",
    "under"   => "LOC",
    "through" => "DIR2",
    "after"   => "TWHEN",
);

my %mlemma2functor = (
    "n\'t"      => "RHEM",
    "not"       => "RHEM",
    "only"      => "RHEM",
    "just"      => "RHEM",
    "even"      => "RHEM",
    "nearly"    => "EXT",
    "also"      => "RHEM",
    "too"       => "RHEM",
    "both"      => "RSTR",
    "rapidly"   => "EXT",
    "much"      => "EXT",
    "mainly"    => "EXT",
    "very"      => "EXT",
    "currently" => "TWHEN",
    "soon"      => "TWHEN",
    "sooner"    => "TWHEN",
);

my %afun2functor = (
    "Apos" => "APPS",
);

my %temporal_noun;
foreach (
    qw(
    sunday monday tuesday wednesday thursday friday saturday
    january february march april may june july august september october november december
    spring summer autumn winter
    year month week day hour minute
    today yesterday tomorrow
    morning evening noon afternoon
    period time
    when now
    )
    )
{
    $temporal_noun{$_} = 1;
}

sub assign_functors {
    my ($t_root) = @_;

    NODE: foreach my $node ( grep { not defined $_->functor } $t_root->get_descendants ) {

        #        my $lex_a_node  = $document->get_node_by_id( $node->get_attr('a/lex.rf') );
        my $lex_a_node = $node->get_lex_anode;

        if ( not defined $lex_a_node ) {
            $node->set_functor('???');
            next NODE;
        }

        my $a_parent    = $lex_a_node->get_parent;
        my $afun        = $lex_a_node->afun;
        my $mlemma      = lc $lex_a_node->lemma;     #Monday -> monday
        my @aux_a_nodes = $node->get_aux_anodes();
        my ($first_aux_mlemma) = map { $_->lemma } grep { $_->tag eq "IN" } @aux_a_nodes;
        $first_aux_mlemma = '' if !defined $first_aux_mlemma;

        my $functor;

        if ( $node->get_parent() == $t_root ) {
            $functor = 'PRED'
        }
        elsif ( defined $temporal_noun{$mlemma} and ( not @aux_a_nodes or $first_aux_mlemma =~ /^(in|on)$/ ) ) {
            $functor = "TWHEN";
        }
        elsif ( defined $temporal_noun{$mlemma} and $first_aux_mlemma eq "from" ) {
            $functor = "TSIN";
        }
        elsif ( defined $temporal_noun{$mlemma} and $first_aux_mlemma eq "to" ) {
            $functor = "TTILL";
        }
        elsif ( $functor = $mlemma2functor{ $node->t_lemma } ) {
        }
        elsif ( $functor = $tag2functor{ $lex_a_node->tag } ) {
        }
        elsif ( defined $afun and $functor = $afun2functor{$afun} ) {
        }
        elsif ( ($functor) = grep {$_} map { $aux2functor{ $_->lemma } } @aux_a_nodes ) {
        }
        elsif (
            $lex_a_node->tag =~ /^(N.+|WP|PRP|WDT)$/
            and $a_parent->tag
            =~ /^V/
            and $lex_a_node->ord < $a_parent->ord
            )
        {
            if ( $node->get_parent->is_passive ) {
                $functor = "PAT";
            }
            else {
                $functor = "ACT";
            }
        }
        elsif (
            $a_parent->tag
            =~ /^V/
            and $lex_a_node->ord > $a_parent->ord
            )
        {
            $functor = "PAT";
        }
        elsif ( $a_parent->tag =~ /^N/ ) {
            $functor = 'RSTR';
        }
        elsif ( $lex_a_node->tag =~ /^V/ ) {
            $functor = 'PAT';
        }
        else {
            $functor = '???';
        }
        $node->set_functor($functor);

        #    print $node->t_lemma."\t$functor ($first_aux_mlemma) [temporal $mlemma =>$temporal_noun{$mlemma}]\n\n";
    }
}

sub process_ttree {
    my ( $self, $t_root ) = @_;
    assign_functors($t_root);
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::SetFunctors

This block assings functors to English t-nodes.
The procedure is based
on a few heuristic rules and conversion tables from functional words and POS tags to functors.
Simple lexical lists are used too.
In each t-node, the resulting functor (or value '???') is stored in the C<functor> attribute.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

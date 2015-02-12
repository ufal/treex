package Treex::Block::T2T::EN2CS::TrLFPhrases;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::ML::NormalizeProb;

# TODO: it is taking the place of... #make use of
Readonly my $CHILD_PARENT_TO_ONE_NODE => {
    prime_minister => 'premiér#N',
    Dalai_Lama     => 'dalajláma#N',
    use_make       => 'použít#V|využít#V|používat#V|využívat#V',
    place_take     => 'konat_se#V|proběhnout#V|probíhat#V',
    happy_make     => 'potěšit#V|těšit#V',
    this_time      => 'tentokrát#D',
    that_time      => 'tehdy#D',
    first_time     => 'poprvé#D',
    second_time    => 'podruhé#D',
    third_time     => 'potřetí#D',
    last_time      => 'naposledy#D',
};

sub process_ttree {
    my ( $self, $cs_troot ) = @_;
    my @cs_tnodes = $cs_troot->get_descendants( { ordered => 1 } );

    # Hack for "That is," -> "Jinými slovy"
    if ( $cs_troot->src_tnode->get_zone->sentence =~ /^That is,/ ) {
        my ( $that, $is ) = @cs_tnodes;
        if ( $that->t_lemma eq 'that' && $is->t_lemma eq 'be' ) {
            $that->remove();
            shift @cs_tnodes;
            $is->set_attr( 'mlayer_pos', 'X' );
            $is->set_t_lemma('Jinými slovy');
            $is->set_t_lemma_origin('rule-Translate_LF_phrases');
            $is->set_formeme('x');
            $is->set_formeme_origin('rule-Translate_LF_phrases');
        }
    }

    foreach my $cs_tnode (@cs_tnodes) {
        $self->process_tnode($cs_tnode);
    }
    return;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    my $en_tnode = $cs_tnode->src_tnode or return;
    my ( $lemma, $formeme ) = $en_tnode->get_attrs(qw(t_lemma formeme));
    my $en_parent = $en_tnode->get_parent();
    return if $en_parent->is_root();
    my $cs_parent = $cs_tnode->get_parent();

    # We don't want to apply one rule (e.g. take_place -> konat_se) more times
    # e.g. in sentence "It took place mostly in the places which ...".
    return if $cs_parent->t_lemma_origin eq 'rule-TrLFPhrases';
    my ( $p_lemma, $p_formeme ) = $en_parent->get_attrs(qw(t_lemma formeme));

    # this/last year
    if ( $lemma =~ /^(this|last)$/ && $p_lemma eq 'year' ) {

        # "this year's X" -> "letošní X"
        if ( $p_formeme eq 'n:poss' ) {
            my $l = $lemma eq 'this' ? 'letošní' : 'loňský';
            $cs_parent->set_t_lemma($l);
            $cs_parent->set_t_lemma_origin('rule-TrLFPhrases');
            $cs_parent->set_attr( 'mlayer_pos', 'A' );
            $cs_parent->set_formeme('adj:attr');
            $cs_parent->set_formeme_origin('rule-TrLFPhrases');
            foreach my $child ( $cs_tnode->get_children() ) {
                $child->set_parent($cs_parent);
            }
            $cs_tnode->remove();
            return;
        }

        # "this year" -> "letos"
        if ( $p_formeme =~ /^n:(adv|than.X)$/ ) {
            my $l = $lemma eq 'this' ? 'letos' : 'vloni';
            my $f = $p_formeme =~ /adv/ ? 'adv:' : 'n:než+X';
            $cs_parent->set_attr( 'mlayer_pos', 'D' );
            $cs_parent->set_t_lemma($l);
            $cs_parent->set_formeme($f);
            $cs_parent->set_t_lemma_origin('rule-TrLFPhrases');
            $cs_parent->set_formeme_origin('rule-TrLFPhrases');
            foreach my $child ( $cs_tnode->get_children() ) {
                $child->set_parent($cs_parent);
            }
            $cs_tnode->remove();
            return;
        }

        # "by the end of last year" -> "koncem loňského roku"
        # But don't solve here: "in last years" -> "v posledních letech"
        if ( $en_parent->gram_number eq 'sg' ) {
            my $l = $lemma eq 'this' ? 'letošní' : 'loňský';
            $cs_tnode->set_t_lemma($l);
            $cs_tnode->set_t_lemma_origin('rule-TrLFPhrases');
            $cs_tnode->set_attr( 'mlayer_pos', 'A' );
            return;
        }
        return;
    }

    # "for example" -> "například"
    # Parsing might be wrong, better to look for this as a phrase
    if ( $lemma =~ /^(example|instance)$/ ) {
        my $en_anode = $en_tnode->get_lex_anode() or return;
        my $a_for    = $en_anode->get_prev_node() or return;
        if ( $a_for->lemma eq 'for' ) {
            $cs_tnode->set_attr( 'mlayer_pos', 'D' );
            $cs_tnode->set_t_lemma('například');
            $cs_tnode->set_t_lemma_origin('rule-TrLFPhrases');
            $cs_tnode->set_formeme('x');
            $cs_tnode->set_formeme_origin('rule-TrLFPhrases');
            return;
        }
    }

    # "be worth" -> "mit cenu"
    if ( $lemma eq 'worth' && $en_parent->t_lemma eq 'be' ) {
        $cs_parent->set_t_lemma('mít');
        $cs_parent->set_t_lemma_origin('rule-TrLFPhrases');
        $cs_parent->set_attr( 'mlayer_pos', 'V' );
        $cs_tnode->set_formeme('n:4');
        $cs_tnode->set_formeme_origin('rule-TrLFPhrases');
    }

    # "based on" -> "na základě"
    if ( $lemma eq 'base' && $en_tnode->is_passive && $p_formeme =~ /^v/ ) {
        my $child = first { $_->src_tnode->formeme eq 'n:on+X' } $cs_tnode->get_echildren();
        return if !$child;

        $cs_tnode->set_t_lemma('základ');
        $cs_tnode->set_t_lemma_origin('rule-TrLFPhrases');
        $cs_tnode->set_formeme('n:na+6');
        $cs_tnode->set_formeme_origin('rule-TrLFPhrases');
        $cs_tnode->set_attr( 'mlayer_pos', 'N' );
        $cs_tnode->set_is_passive(undef);

        $child->set_formeme('n:2');
        $child->set_formeme_origin('rule-TrLFPhrases');
    }

    # Two English t-nodes, child and parent, translates to one Czech t-node
    my $one_node_variants = $CHILD_PARENT_TO_ONE_NODE->{ $lemma . '_' . $p_lemma };
    if ($one_node_variants) {
        my @variants = split /\|/, $one_node_variants;
        my $uniform_logprob = Treex::Tool::ML::NormalizeProb::prob2binlog( 1 / @variants );
        $cs_parent->set_attr(
            'translation_model/t_lemma_variants',
            [   map {
                    my ( $cs_lemma, $m_pos ) = split /#/, $_;
                    {   't_lemma' => $cs_lemma,
                        'pos'     => $m_pos,
                        'origin'  => 'TrLFPhrases',
                        'logprob' => $uniform_logprob,
                    }
                    } @variants
            ]
        );
        my ( $cs_lemma, $m_pos ) = split /#/, $variants[0];
        $cs_parent->set_attr( 'mlayer_pos', $m_pos );
        $cs_parent->set_t_lemma($cs_lemma);
        $cs_parent->set_t_lemma_origin('rule-TrLFPhrases');

        if ( $m_pos eq "D" ) {    # for the first time -> * pro poprve
            $cs_parent->set_formeme('adv');
            $cs_parent->set_formeme_origin('rule-TrLFPhrases');
        }

        foreach my $child ( $cs_tnode->get_children() ) {
            $child->set_parent($cs_parent);
        }
        $cs_tnode->remove();
    }
    return;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFPhrases

Try to apply some hand written rules for phrases translation.
This block serves as an experimental (and temporary, I hope) place,
where we try rules in order to learn them automatically from data with ML in future.

=back

=cut

# Copyright 2009-2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

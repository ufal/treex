package Treex::Block::A2T::EN::SetFormeme;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

use Readonly;

Readonly my $DEBUG => 0;

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @root_descendants = $t_root->get_descendants();

    # 1. Fill formemes (but use just n:obj instead of n:obj1 and n:obj2)
    foreach my $t_node (@root_descendants) {
        my $formeme = detect_formeme($t_node);
        $t_node->set_formeme($formeme);
    }

    # 2. Distinguishing two object types (first and second) below bitransitively used verbs
    foreach my $t_node (@root_descendants) {
        next if $t_node->formeme !~ /^v:/;
        distinguish_objects($t_node);
    }
    return 1;
}

Readonly my %SUB_FOR_SEMPOS => (
    n   => \&_noun,
    adj => \&_adj,
    adv => sub {'adv:'},
    v   => \&_verb,
);

sub detect_formeme {
    my ($t_node) = @_;

    # Non-complex type nodes (coordinations, rhematizers etc.)
    # have special formeme value instead of undef,
    # so tedious undef checking (||'') is no more needed.
    return 'x' if $t_node->nodetype ne 'complex';

    # Punctuation in most cases should not remain on t-layer, but anyway
    # it makes no sense detecting formemes. (These are not unrecognized ???.)
    return 'x' if $t_node->t_lemma =~ /^([.;:-]|''|``)$/;

    # If no lex_anode is found, the formeme is unrecognized
    my $a_node = $t_node->get_lex_anode() or return '???';

    my $sempos = $t_node->get_attr('gram/sempos');
    $sempos =~ s{\..*}{};

    # Choose the appropriate subroutine according to the sempos
    my $sub_ref = $SUB_FOR_SEMPOS{$sempos};
    return $sub_ref->( $t_node, $a_node ) if $sub_ref;

    # If no such subroutine found, the formeme is unrecognized
    return '???';
}

# semantic nouns
sub _noun {
    my ( $t_node, $a_node ) = @_;
    return 'n:poss' if $a_node->tag eq 'PRP$';

    #TODO: my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    # When  aux_anodes are not ordered, we have formemes like
    # v:to_order_in (instead of v:in_order_to), n:to_up+X (instead of n:up_to+X) etc.
    # On the target side there is the same error, so we have Czech formemes like n:v_než+X.
    # However, formemes dictionaries are saved with this wrong mapping,
    # so they must be repaired first.
    # TODO: Also postpositons are not handled: n:ago+X instead of n:X+ago
    my @aux_a_nodes = $t_node->get_aux_anodes();

    my $prep = get_aux_string(@aux_a_nodes);
    return "n:$prep+X" if $prep;

    # specialni zpracovani pro potomka rootu,
    # protoze pro root nefunguje get_lex_anode, ktery je jinak lepsi
    my ($parent_t_node) = $t_node->get_eff_parents();
    my $parent_a_node =
        $parent_t_node->is_root()
        ? ( $a_node->get_eff_parents )[0]
        : $parent_t_node->get_lex_anode();

    # treba v pedt v konstrukcich s #Equal rodic nema a-uzel
    return 'n:???' if !$parent_a_node;
    my $parent_tag = $parent_a_node->tag || '';
    my $afun = $a_node->afun;

    if ( $parent_tag =~ /^V/ ) {

        # Let's have e.g.: "This year(afun=Adv), there were many errors in MT."
        # "year" is a semantic noun, but not subject nor object.
        # What formeme should it have? Martin Popel proposes n:adv.
        return 'n:adv'  if $afun eq 'Adv';
        return 'n:subj' if $afun eq 'Sb';
        return 'n:obj'  if $afun eq 'Obj';

        # If something went wrong (parser and consequently afun=NR)
        # try a guess - it is better than having formeme 'n:'.
        return 'n:subj' if $a_node->precedes($parent_a_node);
        return 'n:obj';
    }
    return 'n:poss' if grep { $_->tag eq 'POS' } @aux_a_nodes;
    return 'n:attr' if below_noun($t_node) || below_adj($t_node);
    my ( $lemma, $id ) = $t_node->get_attrs( 't_lemma', 'id' );
    Report::warn("Formeme n: $lemma $id") if $DEBUG;
    return 'n:';
}

# semantic adjectives
sub _adj {
    my ( $t_node, $a_node ) = @_;

    #TODO: my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my @aux_a_nodes = $t_node->get_aux_anodes();
    my $prep        = get_aux_string(@aux_a_nodes);
    return "adj:$prep+X" if $prep;
    return 'adj:attr'    if below_noun($t_node) || below_adj($t_node);
    return 'adj:compl'   if below_verb($t_node);
    return 'adj:';
}

# semantic verbs
sub _verb {
    my ( $t_node, $a_node ) = @_;

    #TODO: my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my @aux_a_nodes = $t_node->get_aux_anodes();
    my $tag         = $a_node->tag;

    if ( $t_node->get_attr('is_infin') ) {
        ## TODO: !!! vyresit jeste 'in order to'
        return 'v:to+inf' if any { $_->lemma eq 'to' } @aux_a_nodes;
        return 'v:inf';
    }

    my $subconj = get_subconj_string(@aux_a_nodes);
    my $has_non_VBG_verb_aux = any { $_->tag =~ /^VB[^G]?$/ } @aux_a_nodes;

    if ( $tag eq 'VBG' && !$has_non_VBG_verb_aux ) {
        return "v:$subconj+ger" if $subconj;
        return 'v:attr'         if below_noun($t_node);
        return 'v:ger';
    }

    if ( $t_node->get_attr('is_clause_head') ) {
        return "v:$subconj+fin" if $subconj;                                  # podradici veta spojkova
        return 'v:rc'           if $t_node->get_attr('is_relclause_head');    # podradici veta vztazna
        return 'v:fin';
    }

    if ( $tag =~ /VB[DN]/ && !$has_non_VBG_verb_aux ) {
        return 'v:attr' if below_noun($t_node);
        return 'v:fin';
    }

    if (any { $_->form =~ /^[Hh]aving$/ }
        @aux_a_nodes
        and
        any { $_->tag eq 'TO' } @aux_a_nodes
        )
    {    # having to + infinitive
        return "v:$subconj+ger" if $subconj;
        return 'v:ger';
    }

    return "v:$subconj+???" if $subconj;

    # TODO:tady jeste muze byt vztazna !!!
    return 'v:fin';
}

sub get_aux_string {
    my @preps_and_conjs = grep { is_prep_or_conj($_) } @_;
    return join '_', map { $_->lemma } @preps_and_conjs;
}

sub is_prep_or_conj {
    my ($a_node) = @_;
    return 1 if $a_node->afun =~ /Aux[CP]/;

    # If afun is not reliable, try also tag
    return 1 if $a_node->tag =~ /^(IN|TO)$/;

    # Postposition "ago" is now covered by afun AuxP
    # return 1 if $a_node->form eq 'ago';
    return 0;
}

sub get_subconj_string {
    my @aux_a_nodes = @_;
    return join '_', map { $_->lemma }
        grep { $_->tag eq 'IN' || $_->afun eq 'AuxC' }
        @aux_a_nodes;
}

sub below_noun {
    my $tnode = shift;
    my ($eff_parent) = $tnode->get_eff_parents() or return 0;
    return ( $eff_parent->get_attr('gram/sempos') || '' ) =~ /^n/;    #/^[n|adj]/;
}

sub below_adj {
    my $tnode = shift;
    my ($eff_parent) = $tnode->get_eff_parents() or return 0;
    return ( $eff_parent->get_attr('gram/sempos') || '' ) =~ /^adj/;
}

sub below_verb {
    my $tnode = shift;
    my ($eff_parent) = $tnode->get_eff_parents() or return 0;
    return ( $eff_parent->get_attr('gram/sempos') || '' ) =~ /^v/;
}

sub distinguish_objects {
    my ($t_node) = @_;
    my @objects = grep { $_->formeme =~ /^n:obj/ }
        $t_node->get_eff_children( { ordered => 1 } );

    return if !( @objects > 1 );

    my @firsts;
    while (@objects) {
        push @firsts, shift @objects;
        last if @objects == 0
                || !$firsts[0]->is_member
                || $firsts[0]->get_parent() != $objects[0]->get_parent();

    }

    # If both the sets of first- and second-position objects are non-empty
    if ( @firsts and @objects ) {
        foreach my $first (@firsts) {
            $first->set_formeme('n:obj1');
        }
        foreach my $second (@objects) {
            $second->set_formeme('n:obj2');
        }
    }
    return;
}

1;

__END__

=over

=item Treex::Block::A2T::EN::SetFormeme

The attribute C<formeme> of SEnglishT nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

=back

=cut

# Copyright 2008 - 2009 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

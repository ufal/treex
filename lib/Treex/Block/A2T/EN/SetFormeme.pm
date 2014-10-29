package Treex::Block::A2T::EN::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my $DEBUG => 0;

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @root_descendants = $t_root->get_descendants();

    # 0. Fill syntpos (avoid using sempos)
    foreach my $t_node (@root_descendants) {
        my $syntpos = $self->detect_syntpos($t_node);
        $t_node->set_attr('syntpos', $syntpos); # no need to store it in the wild attributes (used only in this block)
    }

    # 1. Fill formemes (but use just n:obj instead of n:obj1 and n:obj2)
    foreach my $t_node (@root_descendants) {
        my $formeme = $self->detect_formeme($t_node);
        $t_node->set_formeme($formeme);
    }

    # 2. Distinguishing two object types (first and second) below bitransitively used verbs
    foreach my $t_node (@root_descendants) {
        next if $t_node->formeme !~ /^v:/;
        $self->distinguish_objects($t_node);
    }
    return 1;
}

Readonly my %SYNTPOS_FOR_TAG => (
    NN => 'n', NNS => 'n', NNP => 'n', NNPS => 'n', '$' => 'n',
    JJ => 'adj', JJR => 'adj', JJS => 'adj',
    PDT => 'adj',
    PRP => 'n', 'PRP$' => 'n',
    VB => 'v', VBP => 'v', VBZ => 'v', VBG => 'v', VBD => 'v', VBN => 'v',
    RB => 'adv', RBR => 'adv', RBS => 'adv',
);

sub detect_syntpos {

    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    
     # coap nodes must have empty syntpos
    return '' if ($t_node->nodetype ne 'complex') && $t_node->t_lemma !~ m/^(%|°|#(Percnt|Deg))/;;
    # let's assume generated nodes are (pro)nouns    
    return 'n' if (!$a_node);
    
    my $tag = $a_node->tag;

    return $SYNTPOS_FOR_TAG{$tag} if ( $SYNTPOS_FOR_TAG{$tag} );

    my $form = lc $a_node->form;

    # 'other pronouns'
    if ( $tag =~ m/^(WP|WRB|WDT|DT|WP\$)$/ ) {
        return ( $form =~ m/^(when|where|why|how)$/ ) ? 'adv' : 'n';
    }

    # numerals
    my ($t_parent) = $t_node->get_eparents({or_topological => 1});
    return 'adj' if ( $tag eq 'CD' && $t_parent && ($t_parent->ord > $t_node->ord ) ); 
    
    return 'n';    # default to noun    
}

sub detect_formeme {
    my ($self, $t_node) = @_;

    # Non-complex type nodes (coordinations, rhematizers etc.)
    # have special formeme value instead of undef,
    # so tedious undef checking (||'') is no more needed.
    return 'x' if $t_node->nodetype ne 'complex' && $t_node->t_lemma !~ m/^(%|°|#(Percnt|Deg))/;

    # Punctuation in most cases should not remain on t-layer, but anyway
    # it makes no sense detecting formemes. (These are not unrecognized ???.)
    return 'x' if $t_node->t_lemma =~ /^([.;:-]|''|``)$/;

    # If no lex_anode is found, the formeme is unrecognized
    my $a_node = $t_node->get_lex_anode() or return '???';

    # Choose the appropriate subroutine according to the syntpos
    my $syntpos = $t_node->get_attr('syntpos');
    
    if ($syntpos eq 'n'){
        return $self->_noun($t_node, $a_node);
    }
    elsif ($syntpos eq 'v'){
        return $self->_verb($t_node, $a_node);
    }
    elsif ($syntpos eq 'adj'){
        return $self->_adj($t_node, $a_node);
    }
    elsif ($syntpos eq 'adv'){
        return 'adv';        
    }
    # If no such subroutine found, the formeme is unrecognized
    return '???';
}

# semantic nouns
sub _noun {
    my ( $self, $t_node, $a_node ) = @_;
    return 'n:poss' if $a_node->tag eq 'PRP$';

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    # TODO: Postpositons are not handled: n:ago+X instead of n:X+ago
    # my @aux_a_nodes = $t_node->get_aux_anodes();

    my $prep = $self->get_aux_string(@aux_a_nodes);
    return "n:$prep+X" if $prep;

    my $parent_a_node = $self->get_parent_anode($t_node, $a_node);

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
    return 'n:attr' if $self->below_noun($t_node) || $self->below_adj($t_node);
    my ( $lemma, $id ) = $t_node->get_attrs( 't_lemma', 'id' );
    log_warn("Formeme n: $lemma $id") if $DEBUG;
    return 'n:';
}

# semantic adjectives
sub _adj {
    my ( $self, $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    # my @aux_a_nodes = $t_node->get_aux_anodes();
    my $prep        = $self->get_aux_string(@aux_a_nodes);
    my $afun        = $a_node->afun;
    
    return "n:$prep+X" if $prep; # adjectives with prepositions are treated as a nominal usage
    return 'adj:attr'  if $self->below_noun($t_node) || $self->below_adj($t_node);
    return 'n:subj'    if $afun eq 'Sb'; # adjectives in the subject positions -- nominal usage
    return 'adj:compl' if $self->below_verb($t_node);
    
    return 'adj:';
}

# semantic verbs
sub _verb {
    my ( $self, $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my $first_verbform = ( first { $_->tag =~ m/^[VM]/ && $_->afun !~ /^Aux[CP]$/ } $t_node->get_anodes( { ordered => 1 } ) ) || $a_node;
    
    my $subconj = $self->get_subconj_string($first_verbform, @aux_a_nodes);

    if ( $t_node->get_attr('is_infin') ) {        
        return "v:$subconj+inf" if ($subconj); # this includes the particle 'to'
        return 'v:inf';
    }

    if ( $first_verbform->tag eq 'VBG' ) {        
        return "v:$subconj+ger" if $subconj;
        return 'v:attr' if $self->below_noun($t_node);
        return 'v:ger';
    }

    if ( $t_node->is_clause_head ) {
        return "v:$subconj+fin" if $subconj;            # subordinate clause with a conjunction
        return 'v:rc' if $t_node->is_relclause_head;    # relative clause
        return 'v:fin';
    }

    if ( $first_verbform->tag =~ /VB[DN]/ ) {
        # if there is a subjunction, it mostly is a finite form (e.g. with ellided auxiliaries: "as compared ..." etc.)
        return "v:$subconj+fin" if $subconj;  
        return 'v:attr' if $self->below_noun($t_node); # TODO -- what about adjectives ?
        return 'v:fin';
    }

    # now we don't know if it's infinitive or not (mostly parsing errors) -- assume finite forms
    return "v:$subconj+fin" if $subconj;

    # TODO:tady jeste muze byt vztazna !!!
    # direct speech, imperatives, parsing errors (which in fact mostly are finite forms, if they're verbs at all)
    return 'v:fin';
}

sub get_aux_string {
    my $self = shift;
    my @preps_and_conjs = grep { $self->is_prep_or_conj($_) } @_;
    return join '_', map { lc $_->form } @preps_and_conjs;
}

sub get_parent_anode {
    my ($self, $t_node, $a_node) = @_;
    # special handling for root node (get_lex_anode does not work for it)
    my ($parent_t_node) = $t_node->get_eparents();
    my $parent_a_node =
        $parent_t_node->is_root()
        ? ( $a_node->get_eparents )[0]
        : $parent_t_node->get_lex_anode();    
}

sub is_prep_or_conj {
    my ($self, $a_node) = @_;
    return 1 if $a_node->afun =~ /Aux[CP]/;

    # If afun is not reliable, try also tag
    return 1 if $a_node->tag =~ /^(IN|TO)$/;

    # Postposition "ago" is now covered by afun AuxP
    # return 1 if $a_node->form eq 'ago';
    return 0;
}

sub get_subconj_string {

    my ($self, $first_verbform, @aux_a_nodes) = @_;
    
    @aux_a_nodes = grep { $_->ord < $first_verbform->ord } @aux_a_nodes; 
    return join '_', map { lc $_->form } grep { $self->is_prep_or_conj($_) } @aux_a_nodes;
}

sub below_noun {
    my ($self, $tnode) = @_;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return ( $eff_parent->get_attr('syntpos') || '' ) =~ /^n/;    #/^[n|adj]/;
}

sub below_adj {
    my ($self, $tnode) = @_;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return ( $eff_parent->get_attr('syntpos') || '' ) =~ /^adj/;
}

sub below_verb {
    my ($self, $tnode) = @_;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return ( $eff_parent->get_attr('syntpos') || '' ) =~ /^v/;
}

sub distinguish_objects {
    my ($self, $t_node) = @_;
    my @objects = grep { $_->formeme =~ /^n:obj/ }
        $t_node->get_echildren( { ordered => 1 } );

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

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of English t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

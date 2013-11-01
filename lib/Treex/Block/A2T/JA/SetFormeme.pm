package Treex::Block::A2T::JA::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my $DEBUG => 0;

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @root_descendants = $t_root->get_descendants();

    # 0. Fill syntpos (avoid using sempos)
    foreach my $t_node (@root_descendants) {
        my $syntpos = detect_syntpos($t_node);
        $t_node->set_attr('syntpos', $syntpos); # no need to store it in the wild attributes (used only in this block)
    }

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

Readonly my %SUB_FOR_SYNTPOS => (
    n   => \&_noun,
    adj => \&_adj,
    adv => sub {'adv'},
    v   => \&_verb,
);

# TODO: can be done better
Readonly my %SYNTPOS_FOR_TAG => (
    Keiyōshi => 'adj'
    Fukushi => 'adv'
    Meishi => 'n'
    Dōshi => 'v'
    Jodōshi => 'v'
);

sub detect_syntpos {

    my ( $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    
     # coap nodes must have empty syntpos
     # return '' if ($t_node->nodetype ne 'complex') && $t_node->t_lemma !~ m/^(%|°|#(Percnt|Deg))/;;
    

    # let's assume generated nodes are (pro)nouns    
    return 'n' if (!$a_node);
    
    my $tag = $a_node->tag;
    $tag =~ s{_.*}{};


    return $SYNTPOS_FOR_TAG{$tag} if ( $SYNTPOS_FOR_TAG{$tag} );

    # TODO: detect "special" cases (if there are any)

    return 'n';    # default to noun    
}

sub detect_formeme {
    my ($t_node) = @_;

    # Non-complex type nodes (coordinations, rhematizers etc.)
    # have special formeme value instead of undef,
    # so tedious undef checking (||'') is no more needed.
    # return 'x' if $t_node->nodetype ne 'complex' && $t_node->t_lemma !~ m/^(%|°|#(Percnt|Deg))/;

    # Punctuation in most cases should not remain on t-layer, but anyway
    # it makes no sense detecting formemes. (These are not unrecognized ???.)
    return 'x' if $t_node->t_lemma =~ /^([.;:-]|''|``)$/;

    # If no lex_anode is found, the formeme is unrecognized
    my $a_node = $t_node->get_lex_anode() or return '???';

    # Choose the appropriate subroutine according to the syntpos
    my $sub_ref = $SUB_FOR_SYNTPOS{$t_node->get_attr('syntpos')};
    return $sub_ref->( $t_node, $a_node ) if $sub_ref;

    # If no such subroutine found, the formeme is unrecognized
    return '???';
}

# semantic nouns
# right now we only use n:<particle> formemes, and some other for special cases
sub _noun {
    my ( $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );

    my $part = get_aux_string(@aux_a_nodes);
    return "n:$part" if $part;

    # TODO?: zpracovani pro potomka rootu

    # TODO: vyresit subj, obj, koordinaci (v zavislosti na predchozich blocich)

    # nominal adjectives
    my $tag = $a_node->tag;
    return 'n:attr' if $tag =~ /_Keiyōdōshi/;

    # This part can probably be ommited
    my $afun = $a_node->afun;
    return 'n:adv'  if $afun eq 'Adv';
    return 'n:subj' if $afun eq 'Sb';
    return 'n:obj'  if $afun eq 'Obj';


    # specialni zpracovani pro potomka rootu,
    # protoze pro root nefunguje get_lex_anode, ktery je jinak lepsi
    #my ($parent_t_node) = $t_node->get_eparents();
    #my $parent_a_node =
    #    $parent_t_node->is_root()
    #    ? ( $a_node->get_eparents )[0]
    #    : $parent_t_node->get_lex_anode();

    # treba v pedt v konstrukcich s #Equal rodic nema a-uzel
    #return 'n:???' if !$parent_a_node;
    #my $parent_tag = $parent_a_node->tag || '';
    #my $afun = $a_node->afun;

    #if ( $parent_tag =~ /^V/ ) {

        # Let's have e.g.: "This year(afun=Adv), there were many errors in MT."
        # "year" is a semantic noun, but not subject nor object.
        # What formeme should it have? Martin Popel proposes n:adv.
    #    return 'n:adv'  if $afun eq 'Adv';
    #    return 'n:subj' if $afun eq 'Sb';
    #    return 'n:obj'  if $afun eq 'Obj';

        # If something went wrong (parser and consequently afun=NR)
        # try a guess - it is better than having formeme 'n:'.
    #    return 'n:subj' if $a_node->precedes($parent_a_node);
    #    return 'n:obj';
    #}
    #return 'n:poss' if grep { $_->tag eq 'POS' } @aux_a_nodes;
    #return 'n:attr' if below_noun($t_node) || below_adj($t_node);

    
    my ( $lemma, $id ) = $t_node->get_attrs( 't_lemma', 'id' );
    log_warn("Formeme n: $lemma $id") if $DEBUG;
    return 'n:';
}

# semantic adjectives
sub _adj {
    my ( $t_node, $a_node ) = @_;

    # we take care of the i-adjectives here, nominal adjectives are processed as nouns

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    # my @aux_a_nodes = $t_node->get_aux_anodes();
    my $part        = get_aux_string(@aux_a_nodes);
    my $afun        = $a_node->afun;
    
    #return "n:$part" if $part; # adjectives with prepositions are treated as a nominal usage
       
    # TODO?: should we distinguish adverb forms of adjectives

    # TODO?: adjectives in subject position

    my $tag = $a_node->tag;
    return 'adj:attr'  if $tag =~ /^Rentaishi/;

    my $stem = get_stem( $a_node );

    #return 'n:subj'    if $afun eq 'Sb'; # adjectives in the subject positions -- nominal usage
    
    # TODO: what if copula is ommited?
    #    -  detect conjugation, if copula is ommited
    
    #return 'adj:compl' if below_verb($t_node);
    
    return "adj:$stem";
}

# semantic verbs
sub _verb {
    my ( $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    #my $first_verbform = ( first { $_->tag =~ m/^[VM]/ && $_->afun !~ /^Aux[CP]$/ } $t_node->get_anodes( { ordered => 1 } ) ) || $a_node;
    

    my $stem = get_stem( $a_node );


    #my $subconj = get_subconj_string($first_verbform, @aux_a_nodes);

    #if ( $t_node->get_attr('is_infin') ) {        
    #    return "v:$subconj+inf" if ($subconj); # this includes the particle 'to'
    #    return 'v:inf';
    #}

    #if ( $first_verbform->tag eq 'VBG' ) {        
    #    return "v:$subconj+ger" if $subconj;
    #    return 'v:attr' if below_noun($t_node);
    #    return 'v:ger';
    #}

    #if ( $t_node->is_clause_head ) {
    #    return "v:$subconj+fin" if $subconj;            # podradici veta spojkova
    #    return 'v:rc' if $t_node->is_relclause_head;    # podradici veta vztazna
    #    return 'v:fin';
    #}

    #if ( $first_verbform->tag =~ /VB[DN]/ ) {
        # if there is a subjunction, it mostly is a finite form (e.g. with ellided auxiliaries: "as compared ..." etc.)
    #    return "v:$subconj+fin" if $subconj;  
    #    return 'v:attr' if below_noun($t_node); # TODO -- what about adjectives ?
    #    return 'v:fin';
    #}

    # now we don't know if it's infinitive or not (mostly parsing errors) -- assume finite forms
    #return "v:$subconj+fin" if $subconj;

    # TODO:tady jeste muze byt vztazna !!!
    # direct speech, imperatives, parsing errors (which in fact mostly are finite forms, if they're verbs at all)
    
    return "v:$stem";
}

sub get_aux_string {
    my @part_and_conjs = grep { is_part_or_conj($_) } @_;
    return join '_', map { $_->lemma } @part_and_conjs;
}

sub is_part_or_conj {
    my ($a_node) = @_;
    return 1 if $a_node->afun =~ /Aux[CP]/;

    # If afun is not reliable, try also tag
    return 1 if $a_node->tag =~ /^(Joshi)$/;

    # Postposition "ago" is now covered by afun AuxP
    # return 1 if $a_node->form eq 'ago';
    return 0;
}

# we use same rules for verb and i-adjective conjugations
sub get_stem {
    my ($a_node) = @_;

    # when there is no difference between lemma and form, we return X as default value
    return "X" if $a_node->lemma eq $a_node->form;

    my @lemma = split //, $a_node->lemma;
    my @form = split //, $a_node->form;
    my $pos = 0; 

    while ( $pos < scalar(@lemma) && $pos < scalar(@form) ) {
        break if !( $lemma[$pos] eq $form[$pos] );
        $pos++;
    }
    
    return "X" if $pos == scalar(@form);

    return substr $a_node->form, $pos;
    
}

sub get_subconj_string {

    my ($first_verbform, @aux_a_nodes) = @_;
    
    @aux_a_nodes = grep { $_->ord < $first_verbform->ord } @aux_a_nodes; 

    return join '_', map { $_->lemma }
        grep { $_->tag =~ /^(IN|TO)$/ || $_->afun =~ /Aux[CP]/ }
        @aux_a_nodes;
}

sub below_noun {
    my $tnode = shift;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return ( $eff_parent->get_attr('syntpos') || '' ) =~ /^n/;    #/^[n|adj]/;
}

sub below_adj {
    my $tnode = shift;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return ( $eff_parent->get_attr('syntpos') || '' ) =~ /^adj/;
}

sub below_verb {
    my $tnode = shift;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return ( $eff_parent->get_attr('syntpos') || '' ) =~ /^v/;
}

sub distinguish_objects {
    my ($t_node) = @_;
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

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::NL::Alpino::SetAdtRel;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Simple conversion of Afuns to ADT relations (see _get_rel() for more)
my %AFUN2REL = (
    'Pred'  => '--',
    'Sb'    => 'su',
    'Obj'   => 'obj1',     # obj1, obj2, pc, ld
    'Adv'   => 'mod',      # mod
    'Atv'   => 'predm',    # predm
    'Atr'   => 'mod',      # mod
    'Pnom'  => 'predc',    # predc
    'AuxV'  => 'vc',       # (will actually work well for us when Aux is on top :-)), use vc
    'Coord' => '',         # use child's labels; give them crd
    'Apos'  => '',         # - " - ?? quite weird
    'AuxT'  => 'se',
    'AuxR'  => 'se',       # (not used)
    'AuxP'  => 'mod',      # pc/hd
    'AuxC'  => 'mod',
    'AuxO'  => '',         # (not used)
    'AuxA'  => 'det',
    'AuxZ'  => 'mod',
    'AuxX'  => '',         # (leave out)
    'AuxG'  => '',         # (leave out)
    'AuxY'  => 'mod',
    'AuxS'  => '',         # (leave out)
    'AuxK'  => '',         # (leave out)
    'ExD'   => 'mod',
);

sub process_atree {
    my ( $self, $aroot ) = @_;

    foreach my $anode ( $aroot->get_descendants( { add_self => 1 } ) ) {
        if ( !$anode->wild->{adt_phrase_rel} ) {
            $anode->wild->{adt_phrase_rel} = $self->_get_phrase_rel($anode);
        }
        if ( !$anode->is_leaf and !$anode->wild->{adt_term_rel} ) {
            $anode->wild->{adt_term_rel} = $self->_get_term_rel($anode);
        }
    }
    return;
}

# The terminal usually has rel="hd", with a few exceptions, dealing with them here
sub _get_term_rel {
    my ( $self, $anode ) = @_;
    my $rel = 'hd';
    $rel = 'crd' if ( $anode->is_coap_root );
    $rel = 'cmp' if ( ( $anode->afun // '' ) eq 'AuxC' );                                                   # TODO check for clause root ??
    $rel = 'cmp' if ( ( $anode->lemma // '' ) =~ /^(om|te)$/ and ( $anode->afun // '' ) =~ /^Aux[VC]$/ );
    return $rel;
}

# Convert formemes + afuns into ADT relations
sub _get_phrase_rel {
    my ( $self, $anode ) = @_;    
    my $afun = $anode->afun // '';

    # technical root + top node
    return 'top' if ( $anode->is_root );
    return '--'  if ( $anode->get_parent->is_root );

    my ($aparent) = $anode->get_eparents( { or_topological => 1 } );

    # conjuncts
    return 'cnj' if ( $anode->is_member );

    # possessives, welk
    if ( $anode->match_iset( 'prontype' => '~pr[ns]', 'poss' => 'poss' ) ) {
        return 'det';
    }
    if ( $anode->iset->prontype and ( $anode->lemma // '' ) =~ /^welke?$/ ) {
        return 'det';
    }

    # objects, attributes, verbal subjects -- distinguished based on formeme
    my ($formeme) = $self->_get_formeme($anode);
    if ( my ($objtype) = $formeme =~ /n:(obj.*)/ ) {

        if ( $aparent->lemma eq 'zijn' and $aparent->is_verb ) {
            return 'predc';    # copula "to be" has a special label
        }
        return $objtype eq 'obj2' ? 'obj2' : 'obj1';
    }
    return 'predc' if ( $formeme =~ /^[nv]:predc/ );
    return 'su' if ( $formeme =~ /^v:subj:/ );
    return 'vc' if ( $formeme =~ /^v:obj:/ );
    return 'mod' if ( $formeme eq 'n:adv' ); 
    
    if ( $formeme =~ /^(adj:attr|n:poss)$/ ) {
        if ( $formeme eq 'adj:attr' and $anode->is_numeral ) {    # attributive numerals
            return 'det';
        }
        return 'mod';
    }
    if ( $formeme eq 'adj:compl' ) {
        return $aparent->lemma eq 'zijn' ? 'predc' : 'obj1';
    }
    if ( $formeme eq 'n:attr' and ( $anode->n_node xor $aparent->n_node ) ) {
        return '{app,mod}';
    }
    
    # copulas with co-indexed ADT nodes that have no t-node
    if ( $afun eq 'Obj' and $aparent->is_verb and $aparent->lemma eq 'zijn' ) {
        return 'predc';
    }

    # prepositional phrases
    if ( ( $aparent->afun // '' ) eq 'AuxP' ) {
        return 'obj1';     # dependent NP has 'obj1'
    }
    if ( $afun eq 'AuxP' and $aparent->is_verb ) {
        return 'pc';       # verbal complements have 'pc', otherwise it will default to 'mod'
    }

    # verbs
    if ( $afun eq 'AuxV' or $anode->iset->pos eq 'verb' ) {
        if ( $aparent->iset->pos eq 'verb' ) {
            return 'vc';    # lexical/auxiliary verbs depending on auxiliaries
        }
        if ( $aparent->is_noun and $anode->iset->verbform eq 'part' ) {
            return 'mod';    # participles as adjectival noun modifiers
        }
        if ( ( $anode->lemma // '' ) eq 'te' and ( $aparent->lemma // '' ) ne 'om' ) {
            return 'vc';     # te (heading an infinitive)
        }
        return 'body';
    }

    # om in om-te + infinitive
    if ( $afun eq 'AuxC' and ( $anode->lemma // '' ) eq 'om' ) {
        my $achild_te = first { ( $_->lemma // '' ) eq 'te' and ( $_->afun // '' ) eq 'AuxV' } $anode->get_children();
        return 'vc' if ($achild_te);
    }

    # default: use the conversion table
    if ( $AFUN2REL{$afun} ) {
        return $AFUN2REL{$afun};
    }

    # default if nothing found there
    return 'mod';
}

# "If the a-node is the topmost a-node belonging to its t-node, return the t-nodes formeme, return '' otherwise"
# I.e. return the formeme for a lex. anode or the topmost conjunction/preposition heading a lex. anode
sub _get_formeme {
    my ( $self, $anode ) = @_;
    my ($tnode) = ( $anode->get_referencing_nodes('a/lex.rf'), $anode->get_referencing_nodes('a/aux.rf') );
    return '' if (!$tnode);
    my ($top_anode) = sort { $a->get_depth() <=> $b->get_depth() } $tnode->get_anodes();
    return ( $tnode->formeme // '' ) if ($top_anode == $anode);
    return '';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::SetAdtRel

=head1 DESCRIPTION

Setting the ADT non-terminal and terminal relations based on context, afuns, parts-of-speech, 
and formemes.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

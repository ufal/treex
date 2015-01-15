package Treex::Block::Write::ADTXML;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

# consecutive IDs for nodes and for coindexing
has '_node_id'   => ( isa => 'Int',     is => 'rw' );
has '_index_ids' => ( isa => 'HashRef', is => 'rw' );

has 'sent_ids' => ( isa => 'Bool', is => 'ro', default => 0 );

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
    print { $self->_file_handle } $self->_process_tree($aroot);
}

sub _process_tree {
    my ( $self, $aroot ) = @_;

    $self->_set_node_id(0);
    $self->_set_index_ids( {} );

    my $out = '<?xml version="1.0" encoding="UTF-8"?><alpino_adt version="1.3">' . "\n";
    if ( $self->sent_ids ) {
        $out .= "<!-- " . $aroot->id . " -->" . "\n";
    }
    $out .= $self->_process_subtree( $aroot, 0 );
    $out .= "</alpino_adt>\n";
    return $out;
}

sub _process_node {
    my ( $self, $anode ) = @_;
    $self->_set_node_id(1);
    my $out = '<?xml version="1.0" encoding="UTF-8"?><alpino_adt version="1.3">' . "\n";
    $out .= '<node cat="top" id="0" rel="top">' . "\n";
    $out .= "\t" . $self->_get_node_str( $anode, '--' ) . "\n";
    $out .= "</node>\n</alpino_adt>\n";
    return $out;
}

sub _process_subtree {
    my ( $self, $anode, $indent ) = @_;

    # TODO handle this better (no-lemma thrown out unless root)
    my $lemma    = $anode->lemma // '';
    my $out      = "\t" x $indent;
    my @prekids  = grep { ( $_->afun // '' ) !~ /Aux[XGK]/ } $anode->get_children( { preceding_only => 1 } );
    my @postkids = grep { ( $_->afun // '' ) !~ /Aux[XGK]/ } $anode->get_children( { following_only => 1 } );

    # for each node with kids, create a nonterminal, then recurse + create terminal
    if ( @prekids or @postkids ) {

        # open the nonterminal, add phrase coindexing for relative clauses
        $out .= '<node id="' . $self->_get_id . '" rel="' . $self->_get_rel($anode) . '"';
        if ( $anode->wild->{coindex_phrase} ) {
            $out .= ' index="' . $self->_get_index_id( $anode->wild->{coindex_phrase} ) . '"';
        }
        $out .= '>' . "\n";

        # recurse into kids (1)
        foreach my $akid (@prekids) {
            $out .= $self->_process_subtree( $akid, $indent + 1 );
        }

        # create the terminal for the head node (except for root and formal relative clause heads)
        if ( !$anode->is_root and !$anode->wild->{is_rhd_head} ) {

            # the terminal usually has rel="hd", with a few exceptions, dealing with them here
            my $rel = $anode->wild->{adt_rel} // 'hd';
            $rel = 'crd' if ( $anode->is_coap_root );
            $rel = 'cmp' if ( ( $anode->afun // '' ) eq 'AuxC' );                                  # TODO check for clause root ??
            $rel = 'cmp' if ( $lemma =~ /^(om|te)$/ and ( $anode->afun // '' ) =~ /^Aux[VC]$/ );
            $out .= ( "\t" x ( $indent + 1 ) ) . $self->_get_node_str( $anode, $rel ) . "\n";
        }

        # recurse into kids (2)
        foreach my $akid (@postkids) {
            $out .= $self->_process_subtree( $akid, $indent + 1 );
        }

        # close the nonterminal
        $out .= "\t" x $indent . "</node>\n";
    }

    # only a terminal node is needed for leaves
    else {
        $out .= $self->_get_node_str($anode) . "\n";
    }

    return $out;
}

# Get string of one (terminal) node corresponding to the given a-node
sub _get_node_str {
    my ( $self, $anode, $rel, $cat ) = @_;
    $rel = defined($rel) ? $rel : $self->_get_rel($anode);
    $cat = defined($cat) ? $cat : '';

    my $id  = $self->_get_id();
    my $out = '<node id="' . $id . '" rel="' . $rel . '"';
    $out .= ' cat="' . $cat . '" ' if ( $cat ne '' );

    if ( $anode->wild->{coindex} ) {
        $out .= ' index="' . $self->_get_index_id( $anode->wild->{coindex} ) . '"';
    }
    if ( ( $anode->lemma // '' ) ne '' ) {
        $out .= ' ' . $self->_get_pos($anode);
        my $lemma = $anode->lemma // '';
        $out .= ' sense="' . $lemma . '"';
    }

    $out .= ' />';
    return $out;
}

# Get consecutive numbers for nodes
sub _get_id {
    my ($self) = @_;
    my $id = $self->_node_id;
    $self->_set_node_id( $id + 1 );
    return $id;
}

sub _get_index_id {
    my ( $self, $id ) = @_;
    if ( !defined $self->_index_ids->{$id} ) {
        $self->_index_ids->{$id} = scalar( keys %{ $self->_index_ids } ) + 1;
    }
    return $self->_index_ids->{$id};
}

# Convert formemes + afuns into ADT relations
sub _get_rel {
    my ( $self, $anode ) = @_;
    my ($tnode) = $anode->get_referencing_nodes('a/lex.rf');
    my $afun = $anode->afun // '';

    # technical root + top node
    if ( $anode->is_root ) {
        return 'top';
    }
    if ( $anode->get_parent->is_root ) {
        return '--';
    }

    if ( $anode->wild->{adt_rel} ) {
        return $anode->wild->{adt_rel};    # overrides e.g. for formal subjects, relative clauses etc.
    }

    my ($aparent) = $anode->get_eparents( { or_topological => 1 } );

    # conjuncts
    if ( $anode->is_member ) {
        return 'cnj';
    }

    # possessives, welk
    if ( $anode->match_iset( 'prontype' => '~pr[ns]', 'poss' => 'poss' ) ) {
        return 'det';
    }
    if ( $anode->iset->prontype and ( $anode->lemma // '' ) =~ /^welke?$/ ) {
        return 'det';
    }

    # objects, attributes -- distinguished based on formeme
    if ($tnode) {
        if ( my ($objtype) = $tnode->formeme =~ /n:(obj.*)/ ) {

            if ( $aparent->lemma eq 'zijn' and $aparent->is_verb ) {
                return 'predc';    # copula "to be" has a special label
            }
            return $objtype eq 'obj2' ? 'obj2' : 'obj1';
        }
        if ( $tnode->formeme =~ /n:.*+X/ ) {
            return 'obj1';
        }
        if ( $tnode->formeme =~ /^(adj:attr|n:poss)$/ ) {
            if ( $tnode->formeme eq 'adj:attr' and $anode->is_numeral ) {    # attributive numerals
                return 'det';
            }
            return 'mod';
        }
        if ( $tnode->formeme eq 'adj:compl' ) {
            return $aparent->lemma eq 'zijn' ? 'predc' : 'obj1';
        }
    }
    elsif ( $afun eq 'Obj' and $aparent->is_verb and $aparent->lemma eq 'zijn' ) {
        return 'predc';                                                      # copulas with co-indexed ADT nodes that have no t-node
    }

    # prepositional phrases
    if ( ( $aparent->afun // '' ) eq 'AuxP' ) {
        return 'obj1';                                                       # dependent NP has 'obj1'
    }
    if ( $afun eq 'AuxP' and $aparent->is_verb ) {
        return 'pc';                                                         # verbal complements have 'pc', otherwise it will default to 'mod'
    }

    # verbs
    if ( $afun eq 'AuxV' or $anode->iset->pos eq 'verb' ) {
        if ( $aparent->iset->pos eq 'verb' ) {
            return 'vc';                                                     # lexical/auxiliary verbs depending on auxiliaries
        }
        if ( $aparent->is_noun and $anode->iset->verbform eq 'part' ) {
            return 'mod';                                                    # participles as adjectival noun modifiers
        }
        if ( ( $anode->lemma // '' ) eq 'te' and ( $aparent->lemma // '' ) ne 'om' ) {
            return 'vc';                                                     # te (heading an infinitive)
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

# Get part of speech and morphology information for a node
sub _get_pos {
    my ( $self, $anode ) = @_;

    my %data = ();

    # part-of-speech
    my $pos = $anode->iset->pos;
    $pos = 'comp' if ( $anode->match_iset( 'conjtype' => 'sub' ) );
    $pos = 'comparative' if ( ( $anode->lemma // '' ) =~ /^(als|dan)$/ and ( $anode->afun // '' ) eq 'AuxP' );
    $pos = 'pron'        if ( $anode->iset->prontype );
    $pos = 'det'         if ( $anode->iset->prontype eq 'art' or $anode->iset->poss eq 'poss' );
    $pos = 'det'         if ( $anode->iset->prontype and ( $anode->lemma // '' ) =~ /^welke?$/ );
    $pos = 'adv'         if ( $anode->iset->prontype and ( $anode->lemma // '' ) eq 'er' );
    $pos = 'vg'          if ( $pos eq 'conj' || ( $anode->afun // '' ) =~ /^(Coord|Apos)$/ );
    $pos = 'prep'        if ( $pos eq 'adp' );
    $pos = 'name'        if ( $anode->iset->nountype eq 'prop' );
    $pos = 'comp'        if ( ( $anode->lemma // '' ) eq 'te' and ( $anode->afun // '' ) eq 'AuxV' );
    $data{'pos'} = $pos;

    # morphology
    if ( $pos =~ /^(noun|pron|name)$/ ) {
        $data{'rnum'} = 'sg' if ( $anode->match_iset( 'number' => 'sing' ) );
        $data{'rnum'} = 'pl' if ( $anode->match_iset( 'number' => 'plur' ) );
    }
    if ( $pos eq 'pron' or ( $pos eq 'det' and $anode->iset->poss eq 'poss' ) ) {
        $data{'refl'} = 'refl' if ( $anode->match_iset( 'reflex' => 'reflexive' ) );
        $data{'per'}  = 'fir'  if ( $anode->match_iset( 'person' => '1' ) );
        $data{'per'}  = 'je'   if ( $anode->match_iset( 'person' => '2' ) );
        $data{'per'}  = 'thi'  if ( $anode->match_iset( 'person' => '3' ) );
        $data{'per'}  = 'u'    if ( $anode->match_iset( 'person' => '2', 'politeness' => 'pol' ) );
    }
    if ( $pos eq 'verb' and $anode->match_iset( 'verbform' => 'fin' ) ) {
        $data{'tense'} = 'present' if ( $anode->match_iset( 'tense' => 'pres' ) );
        $data{'tense'} = 'past'    if ( $anode->match_iset( 'tense' => 'past' ) );
        if ( ( $anode->lemma // '' ) eq 'zullen' and $anode->match_iset( 'tense' => 'pres', 'mood' => 'cnd' ) ) {
            $data{'tense'} = 'past';    # "zou"
        }
    }
    if ( $pos eq 'adj' ) {
        $data{'aform'} = 'base'   if ( $anode->match_iset( 'degree' => 'pos' ) );
        $data{'aform'} = 'compar' if ( $anode->match_iset( 'degree' => 'comp' ) );
        $data{'aform'} = 'super'  if ( $anode->match_iset( 'degree' => 'sup' ) );
    }

    return join( ' ', map { $_ . '="' . $data{$_} . '"' } sort { $a cmp $b } keys %data );
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::ADTXML

=head1 DESCRIPTION

A writer for ADT (Abstract Dependency Trees) XML format used by the Alpino generator.

It requires an a-tree and a t-tree, based on them it converts the dependency relations, POS,
and morphology (roughly) into the format required by Alpino.

This is a work-in-progress, many issues are yet to be resolved.

=head1 PARAMETERS

=over

=item sent_ids

Include commentaries with sentence IDs on the output (for easier debugging).

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

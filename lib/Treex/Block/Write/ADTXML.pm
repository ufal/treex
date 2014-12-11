package Treex::Block::Write::ADTXML;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '_node_id' => ( isa => 'Int', is => 'rw' );

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
    'AuxP'  => 'pc',       # pc/hd
    'AuxC'  => 'cmp',
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
    $self->_set_node_id(0);

    my $out = '<?xml version="1.0" encoding="UTF-8"?><alpino_adt version="1.3">' . "\n";
    $out .= $self->_process_subtree( $aroot, 0 );
    $out .= "</alpino_adt>\n";

    print { $self->_file_handle } $out;
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

    # for each node with kids, create a nonterminal, then recurse + create terminal (with relation 'hd')
    if ( @prekids or @postkids ) {
        $out .= '<node id="' . $self->_get_id . '" rel="' . $self->_get_rel($anode) . '">' . "\n";
        foreach my $akid (@prekids) {
            $out .= $self->_process_subtree( $akid, $indent + 1 );
        }
        $out .= ( "\t" x ( $indent + 1 ) ) . $self->_get_node_str( $anode, 'hd' ) . "\n";
        foreach my $akid (@postkids) {
            $out .= $self->_process_subtree( $akid, $indent + 1 );
        }
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
    $cat = defined($cat) ? $cat : '--';

    my $out = '<node id="' . $self->_get_id . '" rel="' . $rel . '" cat="' . $cat . '" ';
    $out .= $self->_get_pos($anode);
    my $lemma = $anode->lemma // '';
    $out .= ' root="' . $lemma . '" sense="' . $lemma . '" />';
    return $out;
}

# Get consecutive numbers for nodes
sub _get_id {
    my ($self) = @_;
    my $id = $self->_node_id;
    $self->_set_node_id( $id + 1 );
    return $id;
}

# Convert formemes + afuns into ADT relations
sub _get_rel {
    my ( $self, $anode ) = @_;
    my ($tnode) = $anode->get_referencing_nodes('a/lex.rf');
    my $afun = $anode->afun // '';

    # conjuncts
    if ( $anode->is_member ) {
        return 'crd';
    }

    # conjunctions: behave as if using a child of them
    if ( $afun =~ /^(Apos|Coord)$/ ) {
        my ($achild) = $anode->get_children();
        $anode = $achild // $anode;
    }

    # objects
    if ($tnode) {
        if ( my ($objtype) = $tnode->formeme =~ /n:(obj.*)/ ) {
            return $objtype eq 'obj2' ? 'obj2' : 'obj1';
        }
        if ( $tnode->formeme =~ /n:.*+X/ ) {
            return 'obj1';
        }
        if ( $tnode->formeme =~ /^(adj:attr|n:poss)$/ ) {
            return 'mod';
        }
    }

    # verbs
    if ( $afun eq 'AuxV' or $anode->iset->pos eq 'verb' ) {
        if ( grep { $_->iset->pos eq 'verb' } $anode->get_eparents( { or_topological => 1 } ) ) {
            return 'vc';
        }
        elsif ( $anode->get_parent->is_root ) {
            return '--';
        }
        return 'body';
    }

    # default: use the conversion table
    if ( $AFUN2REL{$afun} ) {
        return $AFUN2REL{$afun};
    }

    # default if nothing found there
    return '--';
}

sub _get_pos {
    my ( $self, $anode ) = @_;

    my %data = ();
    my $pos  = $anode->iset->pos;
    $pos = 'comp' if ( $anode->match_iset( 'conjtype' => 'sub' ) );
    $pos = 'comparative' if ( ( $anode->lemma // '' ) =~ /^(als|dan)$/ and ( $anode->afun // '' ) eq 'AuxP' );
    $pos = 'det'  if ( $anode->match_iset( 'prontype' => 'art' ) );
    $pos = 'pron' if ( $anode->iset->prontype );
    $pos = 'vg'   if ( $pos eq 'conj' || ( $anode->afun // '' ) =~ /^(Coord|Apos)$/ );
    $pos = 'prep' if ( $pos eq 'adp' );
    $data{'pos'} = $pos;

    if ( $pos =~ /^(noun|pron)$/ ) {
        $data{'rnum'} = 'sg' if ( $anode->match_iset( 'number' => 'sing' ) );
        $data{'rnum'} = 'pl' if ( $anode->match_iset( 'number' => 'plu' ) );
    }
    if ( $pos eq 'pron' ) {
        $data{'refl'} = 'refl' if ( $anode->match_iset( 'reflex' => 'reflexive' ) );
        $data{'per'}  = 'fir'  if ( $anode->match_iset( 'person' => '1' ) );
        $data{'per'}  = 'je'   if ( $anode->match_iset( 'person' => '2' ) );
        $data{'per'}  = 'thi'  if ( $anode->match_iset( 'person' => '3' ) );
        $data{'per'}  = 'u'    if ( $anode->match_iset( 'person' => '2', 'politeness' => 'pol' ) );
    }
    if ( $pos eq 'verb' and $anode->match_iset( 'verbform' => 'fin' ) ) {
        $data{'tense'} = 'present' if ( $anode->match_iset( 'tense' => 'pres' ) );
        $data{'tense'} = 'past'    if ( $anode->match_iset( 'tense' => 'past' ) );
    }
    if ( $pos eq 'adj' ) {
        $data{'aform'} = 'base'   if ( $anode->match_iset( 'degree' => 'pos' ) );
        $data{'aform'} = 'compar' if ( $anode->match_iset( 'degree' => 'comp' ) );
        $data{'aform'} = 'super'  if ( $anode->match_iset( 'degree' => 'sup' ) );
    }

    return join( ' ', map { $_ . '="' . $data{$_} . '"' } keys %data );
}

1;


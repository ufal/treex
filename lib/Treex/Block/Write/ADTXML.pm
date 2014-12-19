package Treex::Block::Write::ADTXML;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '_node_id' => ( isa => 'Int', is => 'rw' );

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
    'AuxP'  => 'mod',       # pc/hd
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
    if ( $self->sent_ids ){
        $out .= "<!-- " . $aroot->id . " -->" . "\n";
    }
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
        if (!$anode->is_root){   
            my $rel = $anode->is_coap_root ? 'crd' : 'hd';
            $out .= ( "\t" x ( $indent + 1 ) ) . $self->_get_node_str( $anode, $rel ) . "\n";
        }
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
    $cat = defined($cat) ? $cat : '';

    my $out = '<node id="' . $self->_get_id . '" rel="' . $rel . '" ';
    $out .= 'cat="' . $cat . '" ' if ($cat ne '');
    $out .= $self->_get_pos($anode);
    my $lemma = $anode->lemma // '';
    $out .= ' sense="' . $lemma . '" />';

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
    
    # technical root + top node
    if ( $anode->is_root ){
        return 'top';
    }
    if ( $anode->get_parent->is_root ){
        return '--';
    }
    my ($aparent) = $anode->get_eparents({or_topological=>1});

    # conjuncts
    if ( $anode->is_member ) {
        return 'cnj';
    }
    
    # possessives
    if ( $anode->match_iset( 'prontype' => '~pr[ns]', 'poss' => 'poss' ) ){
        return 'det';
    }

    # objects
    if ($tnode) {
        if ( my ($objtype) = $tnode->formeme =~ /n:(obj.*)/ ) {
            
            if ($aparent->lemma eq 'zijn' and $aparent->is_verb){
                return 'predc';  # copula "to be" has a special label
            }
            return $objtype eq 'obj2' ? 'obj2' : 'obj1';
        }
        if ( $tnode->formeme =~ /n:.*+X/ ) {
            return 'obj1';
        }
        if ( $tnode->formeme =~ /^(adj:attr|n:poss)$/ ) {
            return 'mod';
        }
    }
    
    # prepositional phrases
    if ( ( $aparent->afun // '' ) eq 'AuxP' ){
        return 'obj1';  # dependent NP has 'obj1' 
    }
    if ( $afun eq 'AuxP' and $aparent->is_verb ){
        return 'pc';  # verbal complements have 'pc', otherwise it will default to 'mod'
    }

    # verbs
    if ( $afun eq 'AuxV' or $anode->iset->pos eq 'verb' ) {
        if ( grep { $_->iset->pos eq 'verb' } $anode->get_eparents( { or_topological => 1 } ) ) {
            return 'vc';
        }
        if ( $aparent->is_noun and $anode->iset->verbform eq 'part' ){
            return 'mod';  # participles as adjectival noun modifiers
        }
        return 'body';
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
    my $pos  = $anode->iset->pos;
    $pos = 'comp' if ( $anode->match_iset( 'conjtype' => 'sub' ) );
    $pos = 'comparative' if ( ( $anode->lemma // '' ) =~ /^(als|dan)$/ and ( $anode->afun // '' ) eq 'AuxP' );
    $pos = 'pron' if ( $anode->iset->prontype );
    $pos = 'det'  if ( $anode->iset->prontype eq 'art' or $anode->iset->poss eq 'poss' );
    $pos = 'adv' if ( $anode->iset->prontype and ( $anode->lemma // '' ) eq 'er' );
    $pos = 'vg'   if ( $pos eq 'conj' || ( $anode->afun // '' ) =~ /^(Coord|Apos)$/ );
    $pos = 'prep' if ( $pos eq 'adp' );
    $pos = 'name' if ( $anode->iset->nountype eq 'prop' );
    $data{'pos'} = $pos;

    # morphology
    if ( $pos =~ /^(noun|pron|name)$/ ) {
        $data{'rnum'} = 'sg' if ( $anode->match_iset( 'number' => 'sing' ) );
        $data{'rnum'} = 'pl' if ( $anode->match_iset( 'number' => 'plu' ) );
    }
    if ( $pos eq 'pron' or ( $pos eq 'det' and $anode->iset->poss eq 'poss') ) {
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

    return join( ' ', map { $_ . '="' . $data{$_} . '"' }  sort { $a cmp $b } keys %data );
}

1;


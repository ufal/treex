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

    my $out = "<alpino_adt version=\"1.3\">\n";
    $out .= $self->_process_subtree( $aroot, 0 );
    $out .= "<\/alpino_adt>\n";

    print { $self->_file_handle } $out;
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
        $out .= ( "\t" x ( $indent + 1 ) ) . '<node id="' . $self->_get_id . '" rel="hd" root="' . $lemma . '" />' . "\n";
        foreach my $akid (@postkids) {
            $out .= $self->_process_subtree( $akid, $indent + 1 );
        }
        $out .= "\t" x $indent . "</node>\n";
    }

    # only a terminal node is needed for leaves
    else {
        $out .= '<node id="' . $self->_get_id . '" rel="' . $self->_get_rel($anode) . '" root="' . $lemma . '"/>' . "\n";
    }

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

1;


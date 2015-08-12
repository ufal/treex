package Treex::Block::Write::ADTXML;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

# consecutive IDs for nodes and for coindexing
has '_node_id'   => ( isa => 'Int',     is => 'rw' );
has '_index_ids' => ( isa => 'HashRef', is => 'rw' );

has 'sent_ids' => ( isa => 'Bool', is => 'ro', default => 0 );

has 'prettyprint' => ( isa => 'Bool', is => 'ro', default => 1 );

has 'store_node_ids' => ( isa => 'Bool', is => 'ro', default => 0 );

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
    if ( !$self->prettyprint ) {
        $out =~ s/[\t\r\n]//g;
        $out .= "\n";
    }
    return $out;
}

sub _process_node {
    my ( $self, $anode ) = @_;
    $self->_set_node_id(1);
    my $out = '<?xml version="1.0" encoding="UTF-8"?><alpino_adt version="1.3">' . "\n";
    $out .= '<node cat="top" id="0" rel="top">' . "\n";
    $out .= "\t" . $self->_get_node_str( $anode, '--' ) . "\n";
    $out .= "</node>\n</alpino_adt>\n";
    if ( !$self->prettyprint ) {
        $out =~ s/[\t\r\n]//g;
        $out .= "\n";
    }
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
        $out .= '<node id="' . $self->_get_id . '" rel="' . $anode->wild->{adt_phrase_rel} . '"';
        if ( $anode->wild->{coindex_phrase} ) {
            $out .= ' index="' . $self->_get_index_id( $anode->wild->{coindex_phrase} ) . '"';
        }
        $out .= '>' . "\n";

        # recurse into kids (1)
        foreach my $akid (@prekids) {
            $out .= $self->_process_subtree( $akid, $indent + 1 );
        }

        # create the terminal for the head node (except for root and formal relative clause heads)
        if ( !$anode->is_root and !$anode->wild->{is_formal_head} ) {
            $out .= ( "\t" x ( $indent + 1 ) );
            $out .= $self->_get_node_str( $anode, $anode->wild->{adt_term_rel} ) . "\n";
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
        $out .= $self->_get_node_str( $anode, $anode->wild->{adt_phrase_rel} ) . "\n";
    }

    return $out;
}

# Get string of one (terminal) node corresponding to the given a-node
sub _get_node_str {
    my ( $self, $anode, $rel, $cat ) = @_;
    $cat = defined($cat) ? $cat : '';

    my $id = $self->_get_id();
    if ( $self->store_node_ids ) {    # store node IDs if required by ADT Tree Viterbi
        $anode->{adt_id} = $id;
    }
    my $out = '<node id="' . $id . '" rel="' . $rel . '"';
    $out .= ' cat="' . $cat . '" ' if ( $cat ne '' );

    if ( $anode->wild->{coindex} ) {
        $out .= ' index="' . $self->_get_index_id( $anode->wild->{coindex} ) . '"';
    }
    if ( $anode->wild->{stype} ) {
        $out .= ' stype="' . $anode->wild->{stype} . '"';
    }
    if ( ( $anode->lemma // '' ) ne '' ) {
        $out .= ' ' . $self->_get_pos($anode);
        my $lemma = $anode->lemma // '';
        $out .= ' sense="' . $self->_xml_escape($lemma) . '"';
    }

    $out .= ' />';
    return $out;
}

# Escape XML special characters
sub _xml_escape {
    my ( $self, $text ) = @_;
    $text =~ s/&/\&amp;/g;
    $text =~ s/"/\&quot;/g;
    $text =~ s/'/\&apos;/g;
    $text =~ s/</\&lt;/g;
    $text =~ s/>/\&gt;/g;
    return $text;
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

# Get part of speech and morphology information for a node
sub _get_pos {
    my ( $self, $anode ) = @_;

    my %data = ();

    # part-of-speech
    my $pos = $anode->iset->pos;
    $pos = 'comp' if ( $anode->match_iset( 'conjtype' => 'sub' ) );
    $pos = 'comparative'           if ( ( $anode->lemma // '' ) =~ /^(als|dan)$/ and ( $anode->afun // '' ) eq 'AuxP' );
    $pos = 'pron'                  if ( $anode->iset->prontype );
    $pos = 'det'                   if ( $anode->iset->prontype eq 'art' or $anode->iset->poss eq 'poss' );
    $pos = 'det'                   if ( $anode->iset->prontype and ( $anode->lemma // '' ) =~ /^(deze|die|d[ai]t|welke?)$/ );
    $pos = 'adv'                   if ( $anode->iset->prontype and ( $anode->lemma // '' ) eq 'er' );
    $pos = 'vg'                    if ( $pos eq 'conj' || ( $anode->afun // '' ) =~ /^(Coord|Apos)$/ );
    $pos = 'prep'                  if ( $pos eq 'adp' );
    $pos = 'name'                  if ( $anode->iset->nountype eq 'prop' );
    $pos = 'comp'                  if ( ( $anode->lemma // '' ) eq 'te' and ( $anode->afun // '' ) eq 'AuxV' );
    $pos = 'name'                  if ( $anode->n_node );
    $pos = $anode->wild->{adt_pos} if ( $anode->wild->{adt_pos} );
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

The a-tree must be converted beforehand to an Alpino-ADT-like format so that the output
is actually readable by Alpino (see C<A2T::NL::Alpino::*>).

This is a work-in-progress, many issues are yet to be resolved.

=head1 PARAMETERS

=over

=item sent_ids

Include commentaries with sentence IDs on the output (for easier debugging).

=item prettyprint

Prettyprinting of the output for human readability (default=1).

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

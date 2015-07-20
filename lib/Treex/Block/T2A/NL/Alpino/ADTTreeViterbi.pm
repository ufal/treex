package Treex::Block::T2A::NL::Alpino::ADTTreeViterbi;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;
use Treex::Block::Write::ADTXML;

extends 'Treex::Core::Block';

has _python => ( is => 'rw' );

has _adtxml_writer => ( is => 'rw' );

sub BUILD {

    my ( $self, $params ) = @_;

    # try to find ADT Tree Viterbi Python modules
    # TODO install nicely
    my $tv_path = '.';

    if ( $ENV{TREE_VITERBI_PATH} ) {
        $tv_path = $ENV{TREE_VITERBI_PATH};
    }
    else {
        my $file = __FILE__;
        $file =~ s/\/[^\/]*$//;
        $tv_path = $file . '/tree_viterbi';
        if ( !-d $tv_path ) {
            die('Could not find Tree Viterbi Python modules!');
        }
    }

    # initialize Python
    $self->_set_python( Treex::Tool::Python::RunFunc->new() );

    # import Tree Viterbi module
    $self->_python->command("import sys\nsys.path.append(b'$tv_path')");
    $self->_python->command("import tree_viterbi");

    # load the transition matrix
    $self->_python->command("tree_viterbi.state.init_TM('$tv_path/transmat.mtx')");

    # initialize ADTXML writer (print only one-per-line, store ADT IDs in nodes)
    $self->_set_adtxml_writer( Treex::Block::Write::ADTXML->new( { prettyprint => 0, store_node_ids => 1 } ) );
}

sub process_atree {
    my ( $self, $atree ) = @_;

    # get ADT XML for the current tree, storing ADT IDs in nodes
    my $adtxml = $self->_adtxml_writer->_process_tree($atree);
    chomp $adtxml;
    
    # run Tree Viterbi on the ADT XML, get the result 
    my $out = $self->_python->command("print \"\\t\".join(tree_viterbi.run(u'$adtxml'))");

    # create a mapping (dictionary): ADT ID -> node (for faster lookup)
    my %adt_id_to_node;
    foreach my $anode ( $atree->get_descendants( { add_self => 1 } ) ) {
        if ( defined $anode->{adt_id} ) {
            $adt_id_to_node{ $anode->{adt_id} } = $anode;
        }
    }
    
    # process output, finding the nodes by ID and setting their lemmas
    foreach my $node_str ( split /\t/, $out ) {
        my ( $lemma, $id ) = ( $node_str =~ /^(.*)\/([0-9]+)$/ );
        if ( !defined( $adt_id_to_node{$id} ) ) {
            log_warn( "Cannot find node with id $id, new lemma $lemma (sent ID: " . $atree->id . ")" );
            next;
        }
        # debug print, remove if no longer necessary
        log_info('TreeViterbi: ' . $id . ' ' . $adt_id_to_node{$id}->lemma . ' -> ' . $lemma);

        # set new lemma
        $adt_id_to_node{$id}->set_lemma($lemma);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::ADTTreeViterbi

=head1 DESCRIPTION

A wrapper around Dieke Oele's Tree Viterbi over ADT trees.

To use this block, you have to have the ADT Tree Viterbi code located 
either in a subdirectory of C<treex/lib/Treex/Block/T2A/NL/Alpino/> called
C<tree_viterbi> or in a directory specified by the C<TREE_VITERBI_PATH>
environment variable.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

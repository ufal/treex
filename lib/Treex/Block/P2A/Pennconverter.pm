package Treex::Block::P2A::Pennconverter;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tools::Phrase2Dep::Pennconverter;

has '+language' => ( required => 1 );
has _tool => (
    is  => 'rw',
    isa => 'Treex::Tools::Phrase2Dep::Pennconverter',
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    $self->_set_tool( Treex::Tools::Phrase2Dep::Pennconverter->new($arg_ref) );
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $ptree      = $zone->get_ptree();
        if ( !$zone->has_atree ) {
        log_fatal "TODO: building new a-tree not implemented yet";
    }
    my $a_root = $zone->get_atree();
    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );
    
    my $mrg_string = "( " . $ptree->stringify_as_mrg() . " )\n";
    my ( $parents, $deprels ) = $self->_tool->convert( $mrg_string, 10 );   
    log_fatal "Wrong number of nodes returned:\n"
      . "MRG_STRING=$mrg_string\n"
      . "PARENTS=" . Dumper($parents)
      . "DEPRELS=" . Dumper($deprels)
      if (@$parents != @a_nodes || @$deprels != @a_nodes);
    
    # flatten so there are no temporary cycles introduced
    foreach my $a_node (@a_nodes) {
        $a_node->set_parent($a_root);
    }

    my @all_nodes = ($a_root, @a_nodes);
    foreach my $a_node (@a_nodes) {
        $a_node->set_conll_deprel( shift @$deprels );
        my $index = shift @$parents;
        $a_node->set_parent( $all_nodes[$index] );
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::P2A::Pennconverter - phrase to dependency tress

=head1 DESCRIPTION

This block wraps the Java pennconverter.jar.

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::P2A::Pennconverter;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Phrase2Dep::Pennconverter;

has '+language' => ( required => 1 );
has _tool => (
    is  => 'rw',
    isa => 'Treex::Tool::Phrase2Dep::Pennconverter',
);

has after_rich_np => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'The phrase structure contains rich NP bracketing. '
        . 'E.g. PennTB pathed with annotation by David Vadas.',
);

has after_traces => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'The phrase structure contains traces and function tags.',
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    $self->_set_tool( Treex::Tool::Phrase2Dep::Pennconverter->new($arg_ref) );
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $ptree = $zone->get_ptree();
    my ( $a_root, @a_nodes );
    if ( $zone->has_atree ) {
        $a_root = $zone->get_atree();
        @a_nodes = $a_root->get_descendants( { ordered => 1 } );
    }
    else {
        $a_root  = $zone->create_atree();
        @a_nodes = ();
        my $ord = 1;
        foreach my $terminal ( grep { $_->form } $ptree->get_descendants() ) {

            # skip traces
            next if $terminal->tag =~ /-NONE-/;
            push @a_nodes, $a_root->create_child(
                {
                    form  => $terminal->form,
                    lemma => $terminal->lemma,
                    tag   => $terminal->tag,
                    ord   => $ord++,
                }
            );
        }
    }

    my $mrg_string = $ptree->stringify_as_mrg() . "\n";
    
    # Pennconverter fails on unknown non-terminals,
    # including ROOT (produced by Stanford constituency parser).
    # So let's substitute ROOT with S1.
    $mrg_string =~ s/^\( *ROOT/( S1/;
    
    my ( $parents, $deprels ) = $self->_tool->convert( $mrg_string );
    log_fatal "Wrong number of nodes returned:\n"
        . "MRG_STRING=$mrg_string\n"
        . "PARENTS=" . Dumper($parents)
        . "DEPRELS=" . Dumper($deprels)
        . "ANODES=" . Dumper( [ map { $_->form } @a_nodes ] )
        if ( @$parents != @a_nodes || @$deprels != @a_nodes );

    # flatten so there are no temporary cycles introduced
    foreach my $a_node (@a_nodes) {
        $a_node->set_parent($a_root);
    }

    my @all_nodes = ( $a_root, @a_nodes );
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

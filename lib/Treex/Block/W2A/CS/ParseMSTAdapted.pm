package Treex::Block::W2A::CS::ParseMSTAdapted;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Parser::MST::Czech;

extends 'Treex::Core::Block';

has 'model'        => ( is => 'rw', isa => 'Str' );
has 'model_memory' => ( is => 'rw', isa => 'Str' );

my $parser;

sub process_start {

    my ($self) = @_;

    my $arg_ref = {};
    if ( $self->model ) {
        $arg_ref->{'model'} = $self->model;
    }
    if ( $self->model_memory ) {
        $arg_ref->{'model_memory'} = $self->model_memory;
    }

    unless ($parser) {
        $parser = Treex::Tool::Parser::MST::Czech->new($arg_ref);
        $parser->inititalize;
    }

    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    # delete old topology
    foreach my $a_node (@a_nodes) {
        $a_node->set_parent($a_root);
    }

    my @words = map { $_->form } @a_nodes;
    my @tags  = map { $_->tag } @a_nodes;

    my ( $parents_rf, $afuns_rf ) = $parser->parse_sentence( \@words, \@tags );

    unshift @a_nodes, $a_root;

    foreach my $ord ( 1 .. $#a_nodes ) {
        my $parent_ord = shift @$parents_rf;
        my $afun       = shift @$afuns_rf;
        if ( $afun =~ s/_.+// ) {
            $a_nodes[$ord]->set_is_member(1);
        }
        $a_nodes[$ord]->set_parent( $a_nodes[$parent_ord] );
        $a_nodes[$ord]->set_afun($afun);
    }
}

1;

__END__

=over

=item Treex::Block::W2A::CS::ParseMSTAdapted

Parses analytical trees using McDonald's MST parser adapted by Zdenek Zabokrtsky and Vaclav Novak.

=back

=cut

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by David Marecek

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

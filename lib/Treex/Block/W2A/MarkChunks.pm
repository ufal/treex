package Treex::Block::W2A::MarkChunks;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has min_quotes => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'Minimal length (in words) of a quotation chunk to be marked. Zero means never.',
);

has min_parenthesis => (
    is            => 'ro',
    isa           => 'Int',
    default       => 3,
    documentation => 'Minimal length (in words) of a parenthesis chunk to be marked. Zero means never.',
);

sub process_atree {
    my ( $self, $atree ) = @_;
    my @a_nodes = $atree->get_children( {ordered => 1} );

    my @buffer = ( { type => 'dummy' } );
    for my $i ( 0 .. $#a_nodes ) {
        my $form = $a_nodes[$i]->form;

        if ( $form =~ /^(\(|\[|-LRB-)$/ ) {
            push @buffer, { begin => $i, type => 'parenthesis' };
        }
        elsif ( $form =~ /^(\)|\]|-RRB-)$/ && $buffer[-1]{type} eq 'parenthesis' ) {
            my $top = pop @buffer;
            $self->mark_chunk( 'par', @a_nodes[ $top->{begin} .. $i ] );
        }
        elsif ( $form eq q{``} ) {
            push @buffer, { begin => $i, type => 'quotation' };
        }
        elsif ( $form eq q{''} && $buffer[-1]{type} eq 'quotation' ) {
            my $top = pop @buffer;
            $self->mark_chunk( 'quot', @a_nodes[ $top->{begin} .. $i ] );
        }
    }
    return;
}

sub mark_chunk {
    my ( $self, $type, @a_nodes ) = @_;
    my $min_nodes = $type eq 'par' ? $self->min_parenthesis : $self->min_quotes;

    # Should we mark this type of chunk?
    return if !$min_nodes;

    # Is the chunk long enough to be marked?
    return if @a_nodes < $min_nodes;

    my $name = $type . '-' . $a_nodes[0]->ord;
    foreach my $a_node (@a_nodes) {
        my $chunks = $a_node->get_attr('chunks') || [];
        $a_node->set_attr( 'chunks', [ @$chunks, $name ] );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::Block::W2A::MarkChunks

=head1 DESCRIPTION

Mark chunks (phrases) that are supposed to form a (dependency) subtree
which could be parsed independently on the rest of the sentence.

So far parenthesis and quotation chunks are marked.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

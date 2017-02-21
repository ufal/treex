package Treex::Block::Align::AddTransitiveLinks;
use Moose;
use Treex::Core::Common;
use utf8;

use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';


has 'layer' => (
    is      => 'ro',
    isa     => 'Treex::Type::Layer',
    default => 'a'
);

has '+language' => ( required => 1 );

has 'trg_language' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has 'inter_language' => (
    is      => 'ro',
    isa     => 'Str',
);

has _filters => (
    is => 'ro',
    isa => 'ArrayRef[HashRef]',
    builder => '_build_filters',
    lazy => 1,
);

sub BUILD {
    my ($self) = @_;
    $self->_filters;
}

sub _build_filters {
    my ($self) = @_;
    return [
        { language => $self->inter_language },
        { language => $self->trg_language },
    ];
}

sub process_bundle {
    my ($self, $bundle) = @_;
    
    my $src_tree = $bundle->get_tree($self->language, $self->layer, $self->selector);
    foreach my $src_node ($src_tree->get_descendants({ordered => 1})) {
        my @trg_nodes = Treex::Tool::Align::Utils::aligned_transitively([$src_node], $self->_filters);
        foreach my $trg_node (@trg_nodes) {
            if (!$src_node->is_undirected_aligned_to($trg_node)) {
                $src_node->add_aligned_node($trg_node, 'transitive');
            }
        }
        
    }
}

1;

=head1 NAME 


=head1 DESCRIPTION


=head1 PARAMETERS

=over

=item layer

The layer, most probably C<a> or C<t>. The default is C<a>.

=item language

The source language. Required.

=item selector

The source selector. The default is empty.

=item target_language

The target language. Required.

=item target selector

The target selector. The default is empty.

=item alignment_type

The type of alignment to use.
Actually this is regarded as a regular expression,
so you can use multiple alignments at once
(in such case, be sure to set C<alignment_type_new> as well).

B<Caveats>: if the value given is a substring of another alignment type
(eg. C<'type'> is a substring of C<'type.2'>),
all such alignments will be used (as all of them match the regex)!
If this is not desirable, set C<'^type$'> as C<alignment_type> 
and C<'type'> as C<alignment_type_new> !

The default value is C<intersection>.

=item alignment_type_new

The type of alignment to set for new links. Defaults to C<alignment_type>.

=item match_passes

How many levels of matching are to be tried out.
The higher levels of matching are less accurate,
but still get it right most of the time,
and thus further slightly increase the recall of this block
with little or no decerase in its precision.
The default is 3 (all levels).

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


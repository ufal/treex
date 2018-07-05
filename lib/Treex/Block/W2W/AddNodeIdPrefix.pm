package Treex::Block::W2W::AddNodeIdPrefix;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'prefix' =>
(
    is      => 'ro',
    isa     => 'Str',
    default => ''
);



sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $id = $node->id();
    my $prefix = $self->prefix();
    $id = $prefix.$id;
    $node->set_id($id);
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::AddNodeIdPrefix

=head1 DESCRIPTION

Adds a prefix to the id of every node. It can be a subcorpus identifier.
Then we can index a collection of corpora as one corpus.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

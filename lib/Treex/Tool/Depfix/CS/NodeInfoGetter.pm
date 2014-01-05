package Treex::Tool::Depfix::CS::NodeInfoGetter;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Depfix::NodeInfoGetter';

has 'tag_parts' => ( is => 'rw', isa => 'ArrayRef',
    default => sub { ['pos', 'sub', 'gen', 'num', 'cas', 'pge', 'pnu', 'per', 'ten', 'gra', 'neg', 'voi'] } );

override 'add_tag_split' => sub {
    my ($self, $info, $prefix, $anode) = @_;

    if ( defined $anode ) {
        my @tag_split = split //, $anode->tag;
        foreach my $tag_part (@{$self->tag_parts}) {
            $info->{$prefix.$tag_part} = shift @tag_split;
        }
    } else {
        foreach my $tag_part (@{$self->tag_parts}) {
            $info->{$prefix.$tag_part} = '';
        }
    }

    return ;
};


1;

=head1 NAME

Treex::Tool::Depfix::CS::NodeInfoGetter

=head1 DESCRIPTION

A Depfix block.

Provides methods to get node information in hashes.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


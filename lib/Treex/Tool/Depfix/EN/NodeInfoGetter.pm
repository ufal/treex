package Treex::Tool::Depfix::EN::NodeInfoGetter;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Depfix::NodeInfoGetter';

override 'add_tag_split' => sub {
    my ($self, $info, $prefix, $anode) = @_;

    if ( defined $anode ) {
        $info->{$prefix.'coarsetag'} = substr $anode->tag, 0, 2;
    } else {
        $info->{$prefix.'coarsetag'} = '';
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


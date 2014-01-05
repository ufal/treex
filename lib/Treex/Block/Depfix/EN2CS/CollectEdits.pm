package Treex::Block::Depfix::EN2CS::CollectEdits;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Depfix::CollectEdits';

has '+language' => ( required => 0, default => 'cs' );

use Treex::Tool::Depfix::CS::NodeInfoGetter;
use Treex::Tool::Depfix::EN::NodeInfoGetter;

override '_build_node_info_getter' => sub  {
    return Treex::Tool::Depfix::CS::NodeInfoGetter->new();
};

override '_build_src_node_info_getter' => sub  {
    return Treex::Tool::Depfix::EN::NodeInfoGetter->new();
};

1;

=head1 NAME

Treex::Block::Depfix::EN2CS::CollectEdits

=head1 DESCRIPTION

A Depfix block.

Collects and prints a list of performed edits, comparing the original machine
translation with the reference translation (ideally human post-editation).
To be used to get data to train Depfix.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


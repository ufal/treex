package Treex::Block::A2T::SK::SetFormeme;
use Moose;
use Treex::Core::Common;
use Treex::Block::A2T::SK::SetFormeme::NodeInfo;

extends 'Treex::Block::A2T::CS::SetFormeme';

# This handles the conversion of Slovak->Czech tagset
override '_get_node_info' => sub {

    my ( $self, $t_node ) = @_;

    if ( !$self->_node_info_cache->{ $t_node->id } ) {

        # The actual Slovak-specific differences are hidden in A2T::SK::SetFormeme::NodeInfo
        $self->_node_info_cache->{ $t_node->id } = Treex::Block::A2T::SK::SetFormeme::NodeInfo->new(
            {
                t           => $t_node,
                fix_numer   => $self->fix_numer,
                fix_prep    => $self->fix_prep,
            }
        );
    }
    return $self->_node_info_cache->{ $t_node->id };
};



1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SK::SetFormeme

=head1 DESCRIPTION

Filling Slovak formeme values. This is just a thin layer above the Czech formeme
block, L<Treex::Block::A2T::CS::SetFormeme>, which provides Czech-style POS tags
and a Slovak-specific syntpos. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

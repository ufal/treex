package Treex::Block::Write::AmrAlignedCrossLang;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::AmrAligned';

override '_get_sentence' => sub {
    my ( $self, $ttree ) = @_;
    my ($aligned_ttree) = $self->_get_aligned_ttree($ttree);
    return '' if (!$aligned_ttree);
    return $aligned_ttree->get_zone()->sentence();
};

override '_get_tokens' => sub {
    my ( $self, $ttree ) = @_;
    my ($aligned_ttree) = $self->_get_aligned_ttree($ttree);
    return '' if (!$aligned_ttree);
    my ($atree)         = $aligned_ttree->get_zone()->get_atree;
    return join( ' ', map { $_->form } $atree->get_descendants( { ordered => 1 } ) );
};

override '_get_aligned_anode' => sub {
    my ( $self, $tnode ) = @_;
    my $src_tnode = $tnode->src_tnode();
    return undef if !$src_tnode;
    
    my ($ali_tnode) = $src_tnode->get_aligned_nodes();
    return undef if !$ali_tnode;
    $ali_tnode = $ali_tnode->[0];
    return $ali_tnode->get_lex_anode();
};

sub _get_aligned_ttree {
    my ( $self, $ttree ) = @_;
    my ($src_ttree) = $ttree->src_tnode();    # the source t-ttree

    return if !$src_ttree;
    my ($first_aligned) = first { defined $_ } map {
        my ($ali_nodes) = $_->get_aligned_nodes();
        $ali_nodes ? @$ali_nodes : undef
    } $src_ttree->get_descendants();
    return undef if (!$first_aligned);
    return $first_aligned->get_root();
}

1;

__END__

=head1 NAME

Treex::Block::Write::AmrAlignedCrossLang

=head1 DESCRIPTION

Produces AMR with cross-lingual alignments to the surface (taken from GIZA++). 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Roman Sudarikov <sudarikov@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

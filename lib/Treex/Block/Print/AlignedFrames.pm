package Treex::Block::Print::AlignedFrames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has 'verbs_only' => ( isa => 'Bool', is => 'ro', default => 0 );

sub process_tnode {

    my ($self, $tnode) = @_;

    my $id = $tnode->get_attr('val_frame.rf') or return;
    my ($aligns, $types) = $tnode->get_aligned_nodes();
    return if !$aligns;
    my ($al_tnode) = @$aligns;

    return if ($self->verbs_only and (($al_tnode->gram_sempos // '') ne 'v' ));

    my $al_id = $al_tnode->get_attr('val_frame.rf') // 'NO';
    
    say { $self->_file_handle } join "\t", $tnode->t_lemma, $al_tnode->t_lemma, $id, $al_id;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::AlignedFrames
 
=head1 DESCRIPTION

Print valency frame IDs of aligned t-nodes.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

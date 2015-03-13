package Treex::Block::Print::AlignedFrames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_tnode {
    my ($self, $tnode) = @_;
    my $id = $tnode->get_attr('val_frame.rf') or return;
    my ($aligns, $types) = $tnode->get_aligned_nodes();
    return if !$aligns;
    my ($al_tnode) = @$aligns;
    my $al_id = $al_tnode->get_attr('val_frame.rf') // 'NO';
    
    say { $self->_file_handle } join "\t", $tnode->t_lemma, $al_tnode->t_lemma, $id, $al_id;
    return;
}

1;
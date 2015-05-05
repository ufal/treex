package Treex::Block::T2T::ProjectChangedToA;
use Moose;
extends 'Treex::Core::Block';
use Treex::Core::Common;
use utf8;

has alignment_type => ( is => 'rw', isa => 'Str', default => 'monolingual' );

sub process_ttree {
    my ($self, $troot) = @_;

    # super(); # does not work, dont know why
    
    foreach my $tnode ($troot->get_descendants()) {
        $self->process_tnode($tnode);
    }

    foreach my $tnode ($troot->get_descendants()) {
#        delete $tnode->wild->{changed};
        delete $tnode->wild->{processed};
    }

    return;
}

sub process_tnode {
    my ($self, $tnode) = @_;

    if ($tnode->wild->{changed}) {
        $self->project($tnode);
    }

    return ;
}

sub project {
    my ($self, $tnode) = @_;

    if ( $tnode->wild->{processed} || $tnode->is_root() ) {
        return;
    }

    my $changed = 0;
    
    my $src_tnode = $tnode->src_tnode() // return;

    # lex node
    my $lex = $tnode->get_lex_anode() // return;
    my $src_lex = $src_tnode->get_lex_anode() // return;

    $changed += $self->change($src_lex, $lex);

    # aux nodes
    my %aux = map { ($_->id, $_) } $tnode->get_aux_anodes();
    my %src_aux = map { ($_->id, $_) } $src_tnode->get_aux_anodes();
    
    # aligned aux
    foreach my $id (keys %aux) {
        my $anode = $aux{$id};
        my ($src_anode) = $anode->get_aligned_nodes_of_type($self->alignment_type);
        if (defined $src_anode && defined $src_aux{$src_anode->id}) {
            $changed += $self->change($src_anode, $anode);
            delete $src_aux{$src_anode->id};
            delete $aux{$id};
        }
    }

    # parent
    my ($eparent) = $lex->get_eparents();
    my ($src_eparent) = $src_lex->get_eparents(); # TODO src_lex = coap root
    if (defined $aux{$eparent->id}) {
        if (defined $src_aux{$src_eparent->id}) {
            # match
            $changed += $self->change($src_eparent, $eparent);
            delete $src_aux{$src_eparent->id};
        } else {
            # missing parent
            my $src_new_parent = $src_lex->parent()->create_child();
            if ($eparent->precedes($lex)) {
                $src_new_parent->shift_before_subtree($src_lex);
            } else {
                $src_new_parent->shift_after_subtree($src_lex);
            }
            $src_lex->set_parent($src_new_parent);
            $changed += $self->change($src_new_parent, $eparent);
        }
        delete $aux{$eparent->id};
    } elsif (defined $src_aux{$src_eparent->id}) {
        # surplus parent
        delete $src_aux{$src_eparent->id};
        $src_eparent->remove({children => 'rehang'});
    }

    # unaligned src aux
    foreach my $src_anode (values %src_aux) {
        $src_anode->remove({children => 'rehang'});
        $changed += 1;
    }

    # unaligned aux
    foreach my $anode (values %aux) {
        my $src_new_anode = $src_lex->create_child();
        if ($anode->precedes($lex)) {
            $src_new_anode->shift_before_subtree($src_lex);
        } else {
            $src_new_anode->shift_after_subtree($src_lex);
        }
        $changed += $self->change($src_new_anode, $anode);
    }

    $tnode->wild->{processed} = 1;

    # recurse
    if ($changed) {
        # recurse to parents and children
        my @nodes = ($tnode->get_eparents(), $tnode->get_echildren());
        foreach my $node (@nodes) {
            $self->project($node);
        }
    }

    return $changed;
}

sub change {
    my ($self, $src_anode, $anode) = @_;

    my $changed = 0;
    
    if ( ($anode->lemma // '') ne ($src_anode->lemma // '')
        || ($anode->tag // '') ne ($src_anode->tag // '')
    ) {
        $changed = 1;
        $src_anode->set_lemma($anode->lemma);
        $src_anode->set_form($anode->form);
        $src_anode->set_tag($anode->tag);
    }

    return $changed;
}


1;

=head1 NAME 

WORK IN PROGRESS !!!

=head1 DESCRIPTION

Use case:

=over

=item analyze sentence to a-layer and t-layer (src)

=item copy the t-tree

=item do some changes to the t-tree, mark places of change with tnode->wild->{changed}=1

=item generate a-tree

=item copy parts of the generated a-tree into the src a-tree, but only for nodes that correspond to a changed t-node (if there are some changes to the anodes, proceed to the parent and child tnodes so that changes in morphological agreement are propagated)

=back

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


package Treex::Block::T2T::CS2CS::ProjectChangedToA;
use Moose;
extends 'Treex::Core::Block';
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use utf8;

has alignment_type => ( is => 'rw', isa => 'Str', default => 'monolingual' );

sub process_ttree {
    my ($self, $troot) = @_;

    # super(); # does not work, dont know why
    
    foreach my $tnode ($troot->get_descendants()) {
        $self->process_tnode($tnode);
    }

    foreach my $tnode ($troot->get_descendants()) {
        delete $tnode->wild->{changed};
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
    return if $lex->tag =~ /^Z/;
    my $src_lex = $src_tnode->get_lex_anode() // return;

    $changed += $self->change($src_lex, $lex);

    # aux nodes
    my %aux = map { ($_->id, $_) } grep { $_->tag !~ /^Z/ } $tnode->get_aux_anodes();
    # my %aux = map { ($_->id, $_) } $tnode->get_aux_anodes();
    my %src_aux = map { ($_->id, $_) } grep { $_->tag !~ /^Z/ } $src_tnode->get_aux_anodes();
    # my %src_aux = map { ($_->id, $_) } $src_tnode->get_aux_anodes();
    
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
            my $src_new_parent = $src_lex->parent->create_child(
                lemma => $eparent->lemma,
                form => $eparent->form,
                tag => $eparent->tag,
            );
            if ($eparent->precedes($lex)) {
                $src_new_parent->shift_before_subtree($src_lex);
            } else {
                $src_new_parent->shift_after_subtree($src_lex);
            }
            $src_lex->set_parent($src_new_parent);
            $changed++;
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
    my $last_following = undef;
    foreach my $anode (values %aux) {
        my $src_new_anode = $src_lex->create_child(
            lemma => $anode->lemma,
            form => $anode->form,
            tag => $anode->tag,
        );
        if ($anode->precedes($lex)) {
            $src_new_anode->shift_before_node($src_lex);
        } else {
            $src_new_anode->shift_after_node($last_following // $src_lex);
            $last_following = $src_new_anode;
        }
        $changed++;
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

    # For some reason I get sometimes 15-letter tags
    # and sometimes 16-letter tags (16th position = aspect).
    # Also, the lemmas are in various styles, so I trim them all.
    my $lemma_changed
        = Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma, 1)
        ne Treex::Tool::Lexicon::CS::truncate_lemma($src_anode->lemma, 1);
    my $tag_changed = $anode->tag !~ /^X@/
        && substr($anode->tag, 0, 15) ne substr($src_anode->tag, 0, 15);
    if ($lemma_changed || $tag_changed) {
        $changed = 1;
        $src_anode->set_lemma($anode->lemma);
        $src_anode->set_form($anode->form);
        $src_anode->set_tag($anode->tag);
    }

    return $changed;
}

1;

=pod

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2CS::ProjectChangedToA
-- project only necessary changes to the original a-tree from the generated a-tree,
based on tnode->wild->{changed} attribute.

=head1 SYNOPSIS

 # analyze
 Scen::Analysis::CS
 
 # futurize
 Util::SetGlobal selector=gen
 T2T::CopyTtree source_selector=
 Util::Eval tnode='if (defined $tnode->gram_tense && $tnode->gram_tense ne "post") { $tnode->set_gram_tense("post"); $tnode->wild->{changed}=1; }'
 
 # synthetize
 Scen::Synthesis::CS

 # project changes
 Align::A::MonolingualGreedy to_selector=
 T2T::CS2CS::ProjectChangedToA

 # final polishing
 Util::SetGlobal selector=
 Util::Eval anode='$anode->set_no_space_after("0");'
 A2A::CS::VocalizePreposPlain
 T2A::CS::CapitalizeSentStart
 A2W::Detokenize
 A2W::CS::ApplySubstitutions
 A2W::CS::DetokenizeUsingRules
 A2W::CS::RemoveRepeatedTokens

=head1 DESCRIPTION

This block is useful for the penultimate step in the following scenario (also shown in synopsis):

=over

=item analyze sentence to a-layer and t-layer (src)

=item copy the t-tree

=item do some changes to the t-tree, mark places of change with tnode->wild->{changed}=1

=item generate a-tree

=item copy parts of the generated a-tree into the src a-tree, but only for nodes that correspond to a changed t-node (if there are some changes to the anodes, proceed to the parent and child tnodes so that changes in morphological agreement are propagated)

=item finalize the sentences

=back

TODO: word order is not really handled much.
Generated nodes are put on the left or right side accordingly,
but changes to word order are ignored (actually mostly on purpose).
Especially if the original lex anode becomes something else
(common because auxiliary verbs are lex nodes),
the word order can get quite mixed up.

=head1 PARAMETERS

=over

=item alignment_type

The type of alignment to find source nodes for generated anodes.
Default is C<monolingual>, which is also the default for
L<Treex::Block::Align::A::MonolingualGreedy>.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


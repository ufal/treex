package Treex::Block::Read::CoNLLU;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use File::Slurp;
use Try::Tiny;
extends 'Treex::Block::Read::BaseCoNLLReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $tree ( split /\n\s*\n/, $text ) {
        my @lines  = split( /\n/, $tree );

        # Skip empty sentences (if any sentence is empty at all,
        # typically it is the first or the last one because of superfluous empty lines).
        next unless(@lines);
        my $comment = '';
        my $bundle  = $document->create_bundle();
        # The default bundle id is something like "s1" where 1 is the number of the sentence.
        # If the input file is split to multiple Treex documents, it is the index of the sentence in the current output document.
        # But we want the input sentence number. If the Treex documents are later exported to one file again, the sentence ids should remain unique.
        # Note that this is only the default sentence id for files that do not contain their own sentence ids. If they do, it will be overwritten below.
        my $sentid = $self->sent_in_file() + 1;
        my $sid = $self->sid_prefix().'s'.$sentid;
        $bundle->set_id($sid);
        $self->set_sent_in_file($sentid);
        my $zone = $bundle->create_zone( $self->language, $self->selector );
        my $aroot = $zone->create_atree();
        $aroot->set_id($sid.'/'.$self->language());
        my @parents = (0);
        my @nodes   = ($aroot);
        my $sentence;
        my $printed_up_to = 0;
        # Information about the current fused token (see below).
        my $fufrom;
        my $futo;
        my $fuform;
        my @funodes = ();

        LINE:
        foreach my $line (@lines) {
            next LINE if $line =~ /^\s*$/;
            if ($line =~ s/^#\s*//) {
                if ($line =~ m/sent_id\s+(.*)/) {
                    my $sid = $1;
                    my $zid = $self->language();
                    # Some CoNLL-U files already have sentence ids with "/language" suffix while others don't.
                    if ($sid =~ s-/(.+)$--)
                    {
                        $zid = $1;
                    }
                    # Make sure that there are no additional slashes.
                    $sid =~ s-/.*$--;
                    $zid =~ s-/.*$--;
                    $bundle->set_id( $sid );
                    $aroot->set_id( "$sid/$zid" );
                }
                else {
                    $comment .= "$line\n";
                }
                next LINE;
            }
            my ( $id, $form, $lemma, $upos, $postag, $feats, $head, $deprel, $deps, $misc, $rest ) = split( /\s/, $line );
            log_warn "Extra columns: '$rest'" if $rest;

            # There may be fused tokens consisting of multiple syntactic words (= nodes). For example (German):
            # 2-3   zum   _     _
            # 2     zu    zu    ADP
            # 3     dem   der   DET
            if ($id =~ /(\d+)-(\d+)/) {
                $fufrom = $1;
                $futo = $2;
                $fuform = $form;
                $printed_up_to = $2;
                $sentence .= $form if defined $form;
                $sentence .= ' ' if $misc !~ /SpaceAfter=No/;
                next LINE;
            } elsif ($id > $printed_up_to) {
                $sentence .= $form if defined $form;
                $sentence .= ' ' if $misc !~ /SpaceAfter=No/;
            }

            my $newnode = $aroot->create_child();
            if (defined($futo)) {
                if ($id <= $futo) {
                    push(@funodes, $newnode);
                }
                if ($id >= $futo) {
                    if (scalar(@funodes) >= 2) {
                        for (my $i = 0; $i <= $#funodes; $i++) {
                            my $fn = $funodes[$i];
                            ###!!! Later we will want to make these attributes normal (not wild).
                            $fn->wild->{fused_form} = $fuform;
                            ###!!! The following two lines caused Out of Memory! We should use references instead.
                            #$fn->wild->{fused_start} = $funodes[0];
                            #$fn->wild->{fused_end} = $funodes[-1];
                            $fn->wild->{fused} = ($i == 0) ? 'start' : ($i == $#funodes) ? 'end' : 'middle';
                        }
                    } else {
                        log_warn "Fused token $fufrom-$futo $fuform was announced but less than 2 nodes were found";
                    }
                    $fufrom = undef;
                    $futo = undef;
                    $fuform = undef;
                    splice(@funodes);
                }
            }
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_lemma($lemma);
            # Tred and PML-TQ should preferably display upos as the main tag of the node.
            $newnode->set_tag($upos);
            $newnode->set_conll_cpos($upos);
            $newnode->set_conll_pos($postag);
            $newnode->set_conll_feat($feats);
            $newnode->set_deprel($deprel);
            $newnode->set_conll_deprel($deprel);

            $newnode->iset->set_upos($upos);
            if ($feats ne '_') {
                $newnode->iset->add_ufeatures(split(/\|/, $feats));
            }
            if ($misc && $misc =~ s/(^SpaceAfter=No(\|)?|\|SpaceAfter=No)//){
                $newnode->set_no_space_after(1);
            }
            if ($misc && $misc ne '_'){
                $newnode->wild->{misc} = $misc;
            }
            if ($deps && $deps ne '_'){
                $newnode->wild->{deps} = $deps;
            }

            push @nodes,   $newnode;
            push @parents, $head;
        }
        foreach my $i ( 1 .. $#nodes ) {
            $nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
        }
        $sentence =~ s/\s+$//;
        $zone->set_sentence($sentence);
        $bundle->wild->{comment} = $comment;
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CoNLLU - read CoNLL-U format.

=head1 DESCRIPTION

Document reader for CoNLL-U format for Universal Dependencies.

See L<http://universaldependencies.github.io/docs/format.html>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of sentences (!) per document

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>,
Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

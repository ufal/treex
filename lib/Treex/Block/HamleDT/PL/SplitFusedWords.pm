package Treex::Block::HamleDT::PL::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Splits certain tokens to syntactic words according to the guidelines of the
# Universal Dependencies. This block should be called after the tree has been
# converted to UD, not before!
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $self->mark_multiword_tokens($root);
    # Some of the above transformations may have split or removed nodes.
    # Make sure that the full sentence text corresponds to the nodes again.
    ###!!! Note that for the Prague treebanks this may introduce unexpected differences.
    ###!!! If there were typos in the underlying text or if numbers were normalized from "1,6" to "1.6",
    ###!!! the sentence attribute contains the real input text, but it will be replaced by the normalized word forms now.
    my @nodes = $root->get_descendants({'ordered' => 1});
    my $text = $self->collect_sentence_text(@nodes);
    $zone->set_sentence($text);
}



#------------------------------------------------------------------------------
# Identifies nodes from the original Polish treebank that are part of a larger
# surface token. Marks them as such (multi-word tokens will be visible in the
# CoNLL-U file).

# Pisownia łączna / rozdzielna:
# http://sjp.pwn.pl/zasady/43-Pisownia-laczna-czastek-bym-bys-by-bysmy-byscie;629503.html
# http://sjp.pwn.pl/zasady/44-Pisownia-rozdzielna-czastek-bym-bys-by-bysmy-byscie;629509.html
#------------------------------------------------------------------------------
sub mark_multiword_tokens
{
    my $self = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # Read the words right-to-left. Agglutinating morphemes from the auxiliary
    # verb "być" attach to the preceding word. There are only the following
    # forms: em, m, eś, ś, śmy, ście.
    for(my $i = $#nodes; $i > 0; $i--)
    {
        if($nodes[$i]->lemma() eq 'być' && $nodes[$i]->form() =~ m/^(em|m|eś|ś|śmy|ście)$/i)
        {
            my $fused_form = $nodes[$i-1]->form().$nodes[$i]->form();
            my @mwsequence = ($nodes[$i-1], $nodes[$i]);
            # If the previous word is the conditional particle "by" and the word before that
            # qualifies, they should be written together too. Example: "mógłbym".
            if(lc($nodes[$i-1]->form()) eq 'by' && $i >= 2 && $nodes[$i-2]->form() =~ m/(ł[aoy]?|li)$/i)
            {
                $fused_form = $nodes[$i-2]->form().$fused_form;
                unshift(@mwsequence, $nodes[$i-2]);
            }
            $self->mark_multiword_token($fused_form, @mwsequence);
            $i -= scalar(@mwsequence)-1;
        }
        # In the third person conditional, the "by" occurs without agglutinating morpheme
        # and it may or may not be attached to the preceding word, depending on what the
        # preceding word is. Example: "mógłby".
        # Counter-example:
        # Gdyby tak było, natychmiast by|m zaprotestował.
        # Tady se to "bym" nepřilepuje k předcházejícímu slovu, protože l-příčestí následuje až potom.
        # Odpovídá našemu "aby", "kdyby":
        # Jeżeli nie masz , to by ś na pewno ukrywał , gdyby ś miał .
        # Tady zase Poláci nerozdělili "gdyby", ale to "ś" bude přilepené ke spojce a ne ke slovesu ani k částici "by"!
        elsif(lc($nodes[$i]->form()) eq 'by' && $nodes[$i-1]->form() =~ m/(ł[aoy]?|li)$/i)
        {
            my $fused_form = $nodes[$i-1]->form().$nodes[$i]->form();
            my @mwsequence = ($nodes[$i-1], $nodes[$i]);
            $self->mark_multiword_token($fused_form, @mwsequence);
            $i -= scalar(@mwsequence)-1;
        }
    }
}



#------------------------------------------------------------------------------
# Marks a sequence of existing nodes as belonging to one multi-word token.
#------------------------------------------------------------------------------
sub mark_multiword_token
{
    my $self = shift;
    my $fused_form = shift;
    # The nodes that form the group. They should form a contiguous span in the sentence.
    # And they should be sorted by their ords.
    my @nodes = @_;
    return if(scalar(@nodes) < 2);
    my $fsord = $nodes[0]->ord();
    my $feord = $nodes[-1]->ord();
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $nnw = $nodes[$i]->wild();
        ###!!! Later we will want to make these attributes normal (not wild).
        $nnw->{fused_form} = $fused_form;
        $nnw->{fused_start} = $fsord;
        $nnw->{fused_end} = $feord;
        $nnw->{fused} = ($i == 0) ? 'start' : ($i == $#nodes) ? 'end' : 'middle';
    }
}



#------------------------------------------------------------------------------
# Returns the sentence text, observing the current setting of no_space_after
# and of the fused multi-word tokens (still stored as wild attributes).
#------------------------------------------------------------------------------
sub collect_sentence_text
{
    my $self = shift;
    my @nodes = @_;
    my $text = '';
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $wild = $node->wild();
        my $fused = $wild->{fused};
        if(defined($fused) && $fused eq 'start')
        {
            my $first_fused_node_ord = $node->ord();
            my $last_fused_node_ord = $wild->{fused_end};
            my $last_fused_node_no_space_after = 0;
            # We used to save the ord of the last element with every fused element but now it is no longer guaranteed.
            # Let's find out.
            if(!defined($last_fused_node_ord))
            {
                for(my $j = $i+1; $j<=$#nodes; $j++)
                {
                    $last_fused_node_ord = $nodes[$j]->ord();
                    $last_fused_node_no_space_after = $nodes[$j]->no_space_after();
                    last if(defined($nodes[$j]->wild()->{fused}) && $nodes[$j]->wild()->{fused} eq 'end');
                }
            }
            else
            {
                my $last_fused_node = $nodes[$last_fused_node_ord-1];
                log_fatal('Node ord mismatch') if($last_fused_node->ord() != $last_fused_node_ord);
                $last_fused_node_no_space_after = $last_fused_node->no_space_after();
            }
            if(defined($first_fused_node_ord) && defined($last_fused_node_ord))
            {
                $i += $last_fused_node_ord - $first_fused_node_ord;
            }
            else
            {
                log_warn("Cannot determine the span of a fused token");
            }
            $text .= $wild->{fused_form};
            $text .= ' ' unless($last_fused_node_no_space_after);
        }
        else
        {
            $text .= $node->form();
            $text .= ' ' unless($node->no_space_after());
        }
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}



1;

=over

=item Treex::Block::HamleDT::PL::SplitFusedWords

Splits certain tokens to syntactic words according to the guidelines of the
Universal Dependencies. Some of them have already been split in the original
Polish treebank but at least we have to annotate that they belong to a
multi-word token.

This block should be called after the tree has been converted to Universal
Dependencies so that the tags and dependency relation labels are from the UD
set.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

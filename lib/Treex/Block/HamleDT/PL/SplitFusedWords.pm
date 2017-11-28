package Treex::Block::HamleDT::PL::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::SplitFusedWords';



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
    $zone->set_sentence($root->collect_sentence_text());
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
    # Words written together with the conditional "by".
    # Note that "to" qualifies if it is a conjunction but not if it is a pronoun; we will have to check this separately.
    my $verb_by = '(ł[aoy]?|li)$';
    my $part_by = '^(albo|ależ?|ani|azaliż?|aż|bodaj|byle|chyba|czyż?|gdzież?|jak|jakżeż?|jednak|niech|niechaj|niechżeż?|nuż|oby|otóż|przecież|toć|toż|wszak|wszakoż|wszakże|wszelako|zaliż?)$';
    my $conj_by = '^(aby|aczkolwiek|albo|albowiem|alboż|ale|ani|aż|ażeby|bo|chociaż|choć|czyli|gdyż?|iż|jakkolwiek|jako|jednakże|jeśli|jeżeli|lecz|nim|niż|ponieważ|skoro|tedy|więc|zanim|zaś|zatem|że)$';
    my $by_re = "($verb_by|$part_by|$conj_by)";
    for(my $i = $#nodes; $i > 0; $i--)
    {
        if($nodes[$i]->lemma() eq 'być' && $nodes[$i]->form() =~ m/^(em|m|eś|ś|śmy|ście)$/i)
        {
            my $fused_form = $nodes[$i-1]->form().$nodes[$i]->form();
            my @mwsequence = ($nodes[$i-1], $nodes[$i]);
            # If the previous word is the conditional particle "by" and the word before that
            # qualifies, they should be written together too. Example: "mógłbym".
            if(lc($nodes[$i-1]->form()) eq 'by' && $i >= 2 && ($nodes[$i-2]->form() =~ m/$by_re/i || $nodes[$i-2]->form() =~ m/^to$/i && $nodes[$i-2]->is_conjunction()))
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
        elsif(lc($nodes[$i]->form()) eq 'by' && ($nodes[$i-1]->form() =~ m/$by_re/i || $nodes[$i-1]->form() =~ m/^to$/i && $nodes[$i-1]->is_conjunction()))
        {
            my $fused_form = $nodes[$i-1]->form().$nodes[$i]->form();
            my @mwsequence = ($nodes[$i-1], $nodes[$i]);
            $self->mark_multiword_token($fused_form, @mwsequence);
            $i -= scalar(@mwsequence)-1;
        }
    }
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

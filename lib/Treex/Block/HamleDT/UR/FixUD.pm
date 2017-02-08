package Treex::Block::HamleDT::UR::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_features($root);
}



#------------------------------------------------------------------------------
# Features are stored in conll/feat and their format is not compatible with
# Universal Dependencies.
#------------------------------------------------------------------------------
sub fix_features
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $shakfeatures = $node->conll_feat();
        $shakfeatures = '' if(!defined($shakfeatures) || $shakfeatures eq '_');
        # Discard features with empty values.
        my @shakfeatures = grep {!m/-(any)?$/} (split(/\|/, $shakfeatures));
        # Some features will be preserved in the MISC field.
        my @miscfeatures;
        my @morfeatures;
        my $cat = '_';
        foreach my $feature (@shakfeatures)
        {
            if($feature =~ m/^(chunkId|chunkType|stype)-/)
            {
                $feature =~ s/^(.)/\u$1/;
                $feature =~ s/-/=/;
                push(@miscfeatures, $feature);
            }
            elsif($feature =~ m/^cat-(.*)$/)
            {
                $cat = $1;
            }
            elsif($feature =~ m/^(vib|tam)-/)
            {
                push(@morfeatures, $feature);
                $feature =~ s/^(.)/\u$1/;
                $feature =~ s/-/=/;
                push(@miscfeatures, $feature);
            }
            else
            {
                push(@morfeatures, $feature);
            }
        }
        # Convert the remaining features to Interset.
        # The driver hi::conll also expects the Hyderabad CPOS tag, which we now have in the POS column.
        my $conll_pos = $node->conll_pos();
        my $conll_feat = scalar(@morfeatures)>0 ? join('|', @morfeatures) : '_';
        my $src_tag = "$conll_pos\t$cat\t$conll_feat";
        my $f = decode('hi::conll', $src_tag);
        # Changed features may cause a change of UPOS but it is probably not desirable. Or is it?
        my $tag0 = $node->tag();
        my $tag1 = $f->get_upos();
        if($tag1 ne $tag0)
        {
            # Adjust Interset to the original tag.
            $f->set_upos($tag0);
            unless($tag1 eq 'X')
            {
                unshift(@miscfeatures, "AltTag=$tag0-$tag1");
            }
            # Only replace the original tag if it is an error.
            if($tag0 !~ m/^(NOUN|PROPN|PRON|ADJ|DET|NUM|VERB|AUX|ADV|ADP|CCONJ|SCONJ|PART|INTJ|SYM|PUNCT|X)$/)
            {
                $node->set_tag($tag1);
            }
        }
        $node->set_iset($f);
        # Since we are collecting MISC attributes, let us also do something that does not involve morphological features.
        # The original annotation contained some cycles and we have automatically broken them, using a separate script
        # and preserving the original parent index in the deprel. For example, the deprel is now "punct-CYCLE:7".
        # Let us make the deprel valid again and save the information about the cycle in MISC.
        if($node->deprel() =~ m/^(.+)-CYCLE:(\d+)$/)
        {
            my $deprel = $1;
            my $cycle_head = $2;
            $node->set_deprel($deprel);
            push(@miscfeatures, "CycleHead=$cycle_head");
        }
        ###!!! We do not check the previous contents of MISC because we know that in this particular data it is empty.
        $node->wild()->{misc} = join('|', @miscfeatures);
    }
}



1;

=over

=item Treex::Block::HamleDT::UR::FixUD

This is a temporary block used to prepare the Urdu UD 2.0 treebank.
We got new data from Riyaz Ahmad / IIIT Hyderabad. The dependency relations
already follow the UD v1 guidelines and have to be converted to v2. Features
have to be converted to UD.

The main UD 1 to 2 conversion is done in a separate block.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

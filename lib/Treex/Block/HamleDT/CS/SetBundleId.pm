package Treex::Block::HamleDT::CS::SetBundleId;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Sets the bundle id if it has to be guessed from a-tree root id or other
# sources.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    # We want to preserve the original sentence id. And we want it to appear in bundle id because that will be used when writing CoNLL-U.
    # The bundles in the PDT data have simple ids like this: 's1'.
    # In contrast, the id of the root node of an a-tree reflects the original PDT id: 'a-cmpr9406-001-p2s1' (surprisingly it does not identify the zone).
    # A-tree ids in Faust are different: faust_2010_07_jh_04-SCzechA-p0315-s1-root
    my $sentence_id = $root->id();
    $sentence_id =~ s/^a-//;
    $sentence_id =~ s/-root$//;
    $sentence_id =~ s/-SCzechA//;
    # If there is a hyphen between paragraph and sentence number, remove it.
    $sentence_id =~ s/(-p\d+)-(s[-0-9A-Z]+)$/$1$2/;
    if(length($sentence_id)>1)
    {
        my $bundle = $zone->get_bundle();
        $bundle->set_id($sentence_id);
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::SetBundleId

After importing PDT or a similar treebank to Treex and before further processing
towards UD, it is useful to normalize the various ids. If writing CoNLL-U is
intended, bundle id is important because it will be used as sentence id in the
CoNLL-U file. We typically want it to have three components: document identifier
(a string of lowercase letters and digits, possibly also underscores, hyphens,
periods or colons), followed by -pMsN where M is the paragraph number within the
document, and N is the sentence number within the paragraph (the sentence number
can have a letter after the digits, which may be used if a sentence is later
split to several sentences). This structure may again impact a CoNLL-U file,
where it may be used to detect document and paragraph boundaries.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

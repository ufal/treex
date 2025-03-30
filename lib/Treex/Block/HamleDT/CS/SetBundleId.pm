package Treex::Block::HamleDT::CS::SetBundleId;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



has last_document_id => (is => 'rw', default => '');
has last_sentence_number => (is => 'rw', default => 0);



#------------------------------------------------------------------------------
# Sets the bundle id if it has to be guessed from a-tree root id or other
# sources.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    my $last_document_id = $self->last_document_id();
    my $last_sentence_number = $self->last_sentence_number();
    # We want to preserve the original sentence id. And we want it to appear in bundle id because that will be used when writing CoNLL-U.
    # The bundles in the PDT data have simple ids like this: 's1'.
    # In contrast, the id of the root node of an a-tree reflects the original PDT id: 'a-cmpr9406-001-p2s1' (surprisingly it does not identify the zone).
    # A-tree ids in Faust are different: faust_2010_07_jh_04-SCzechA-p0315-s1-root
    # A-tree ids in PDTSC: hg-13808_03.05-hg-13808_03-1214
    my $document_id = '';
    my $sentence_id = $root->id();
    $sentence_id =~ s/^a-//;
    $sentence_id =~ s/-root$//;
    $sentence_id =~ s/-SCzechA//;
    # If there is a hyphen between paragraph and sentence number, remove it.
    $sentence_id =~ s/(-p[0-9]+)-(s[-0-9A-Z]+)$/$1$2/;
    # Can we now get the document id from the sentence id?
    if($sentence_id =~ m/^(.+)-p[0-9]+s[0-9A-Z]+$/)
    {
        $document_id = $1;
    }
    if($document_id eq '')
    {
        # In PDTSC, a-tree ids tend to repeat the document id but the first instance
        # also has a number of split file (documents were split to files of 50 utterances
        # at most, to make annotation in TrEd easier).
        ###!!! We must at least temporarily keep the split file number in the document
        ###!!! id because individual files, when loaded into Treex, behave like
        ###!!! separate documents.
        if($sentence_id =~ s/^([a-z][a-z](?:-[0-9]+)?_[0-9]+)(\.[0-9]+)-\1-/pdtsc_$1$2-paragraph-/)
        {
            $document_id = "pdtsc_$1$2";
        }
        # Sometimes the sequence of sentence ids in one PDTSC document is interrupted
        # by a wrong sentence id, which makes the sentence look like from a different
        # document. We want to keep it in the document it belongs to! (And we must
        # do it because otherwise the subsequent sentences from the document would
        # get duplicate ids because they would be numbered from 1 again.)
        if($last_document_id =~ m/^pdtsc_/ && $sentence_id =~ m/^a_tree/)
        {
            $document_id = $last_document_id;
            $sentence_id = "$document_id-paragraph-";
        }
    }
    if($document_id eq $last_document_id)
    {
        $last_sentence_number++;
    }
    else
    {
        $last_document_id = $document_id;
        $last_sentence_number = 1;
    }
    # The last part of the sentence id in PDTSC is a mess. Sometimes it is just
    # a number, sometimes it is preceded by "id", "dle" or some other string,
    # sometimes it is followed by "_1", "_2", "x2", "x3" etc. The number itself
    # is not unique and does not correspond to the order of sentences (there
    # could be "d1e478x3", then "1108", then "d1e478x4"). It seems better to
    # throw it away and generate our own sentence number.
    if($last_document_id =~ m/^pdtsc_/)
    {
        $sentence_id =~ s/-paragraph-.*$/-p1s$last_sentence_number/;
    }
    if(length($sentence_id)>1)
    {
        my $bundle = $zone->get_bundle();
        $bundle->set_id($sentence_id);
    }
    $self->set_last_document_id($last_document_id);
    $self->set_last_sentence_number($last_sentence_number);
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

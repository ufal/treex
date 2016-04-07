package Treex::Block::Filter::SDP2015Trees;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Path to list of SDP 2015 sentence IDs, one ID per line.
has 'idlist' => (isa => 'Str', is => 'ro', required => 1);
# Hash of sentence IDs to be retained.
has '_id_hash' => (isa => 'HashRef', is => 'rw', lazy_build => 1, builder => '_build_id_hash');



sub process_document
{
    my $self = shift;
    my $document = shift;
    my $hash = $self->_id_hash();
    my @bundles = $document->get_bundles();
    # Postpone removing bundles until the end. Calling Bundle->remove() multiple times would not be efficient (see also a comment there).
    # Instead, we will do the removing ourselves. (Also, if we removed a bundle during processing the document, the method get_sentence_id()
    # would return wrong result.)
    my @ibundles_to_remove;
    for (my $i = 0; $i < @bundles; ++$i)
    {
        my $sdp_id = $self->get_sentence_id($bundles[$i]);
        if($hash->{$sdp_id})
        {
            $bundles[$i]->set_id($sdp_id);
        }
        else
        {
            # Clean the bundle's content first (to ensure de-indexing).
            foreach my $zone ( $bundles[$i]->get_all_zones() )
            {
                $bundles[$i]->remove_zone( $zone->language(), $zone->selector() );
            }
            push(@ibundles_to_remove, $i);
        }
    }
    while(scalar(@ibundles_to_remove) > 0)
    {
        # Remove the last bundle first so that the indices of the other bundles to remove remain unchanged.
        my $i = pop(@ibundles_to_remove);
        $document->delete_tree($i);
        # Make sure that any attempt by anyone to use the removed bundle will throw an exception.
        # (It will work despite the fact that Bundle is not a descendant of Treex::Core::Node.)
        bless($bundles[$i], 'Treex::Core::Node::Removed');
    }
    return 1;
}



sub _build_id_hash
{
    my $self = shift;
    my $idlist = $self->idlist();
    my %hash;
    open(IDLIST, $idlist) or log_fatal("Cannot read $idlist: $!");
    while(<IDLIST>)
    {
        chomp();
        s/^\s+//;
        s/\s+$//;
        log_warn("Duplicate ID $_ in the filter.") if(exists($hash{$_}));
        $hash{$_}++;
    }
    close(IDLIST);
    return \%hash;
}



#------------------------------------------------------------------------------
# This method has been copied from Write::SDP2015.
#
# Construct sentence number according to Stephan's convention. The result
# should be a numeric string.
#------------------------------------------------------------------------------
sub get_sentence_id
{
    my $self = shift;
    my $bundle = shift;
    my $sid = 0;
    # Option 1: The input file comes from the Penn Treebank / Wall Street Journal
    # and is named according to the PTB naming conventions.
    # Bundle->get_position() is not efficient (see comment there) so we may consider simply counting the sentences using an attribute of this block.
    my $isentence = $bundle->get_position()+1;
    my $ptb_section_file = $bundle->get_document()->file_stem();
    if($ptb_section_file =~ s/^wsj_//i)
    {
        $sid = sprintf("2%s%03d", $ptb_section_file, $isentence);
    }
    # Option 2: The input file comes from the Brown Corpus.
    elsif($ptb_section_file =~ s/^c([a-r])(\d\d)//)
    {
        my $genre = $1;
        my $ifile = $2;
        my $igenre = ord($genre)-ord('a');
        $sid = sprintf("4%02d%02d%03d", $igenre, $ifile, $isentence);
    }
    # Option 3: The input file comes from the Prague Dependency Treebank.
    elsif($ptb_section_file =~ m/^(cmpr|lnd?|mf)(9\d)(\d+)_(\d+)$/)
    {
        my $source = $1;
        my $year = $2;
        my $issue = $3;
        my $ifile = $4;
        my $isource = $source eq 'cmpr' ? 0 : $source =~ m/^ln/ ? 1 : 2;
        $sid = sprintf("1%d%d%04d%03d", $isource, $year, $issue, $ifile);
    }
    else
    {
        log_warn("File name '$ptb_section_file' does not follow expected patterns, cannot construct sentence identifier");
    }
    return $sid;
}



1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::Filter::SDP2015Trees

=head1 SYNOPSIS

This block filters the bundles in the document so that only those bundles
survive that have been included in the SDP 2015 shared task.

During the preparation of the task we first exported all trees from the
participating corpora and later we dropped some exported trees because they
could not be aligned to trees in the other representations. Now we also want to
be able to filter the original treex files and get the same set of trees.

Stephan Oepen has provided a list of sentence IDs that were included in the
shared task data. We must translate the SDP sentence IDs to our bundle IDs and
then select the trees that we want to keep.

=head1 DESCRIPTION

Filters the input document so that only specified sentences are kept. The
bundle ID of these sentences is changed to correspond to the SDP 2015 data.

=head1 ATTRIBUTES

=over

=item C<idlist>

File name (path) of the list of SDP 2015 sentence IDs to keep. One ID per line.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

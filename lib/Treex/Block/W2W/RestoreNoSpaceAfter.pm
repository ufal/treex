package Treex::Block::W2W::RestoreNoSpaceAfter;

use utf8;
use open ':utf8';
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;

extends 'Treex::Core::Block';

# Path to CoNLL-U file with original data.
has 'origconllu' => (isa => 'Str', is => 'ro', required => 1);
# Hash of sentence IDs to be retained.
has '_orig_data' => (isa => 'ArrayRef', is => 'rw', lazy_build => 1, builder => '_build_orig_data');



#------------------------------------------------------------------------------
# Reads the original data from the CoNLL-U file supplied. Creates an array of
# hashes: each hash corresponds either to a new sentence or to a token.
#------------------------------------------------------------------------------
sub _build_orig_data
{
    my $self = shift;
    my $origconllu = $self->origconllu();
    my @array;
    open(ORIG, $origconllu) or log_fatal("Cannot read $origconllu: $!");
    while(<ORIG>)
    {
        chomp();
        if(m/^\#\s*text\s*=\s*(.+)$/)
        {
            my %record =
            (
                'type' => 'sentence',
                'text' => $1
            );
            push(@array, \%record);
        }
        elsif(m/^\d+\t/)
        {
            my @f = split(/\t/, $_);
            my @misc = split(/\|/, $f[9]);
            my $no_space_after = any {m/^SpaceAfter=No$/} (@misc);
            my %record =
            (
                'type' => 'token',
                'form' => $f[1],
                'no_space_after' => $no_space_after
            );
            push(@array, \%record);
        }
        elsif(m/^\d+-\d+\t/)
        {
            log_warn("Multi-word token encountered in $origconllu:");
            log_warn($_);
        }
    }
    close(ORIG);
    return \@array;
}



#------------------------------------------------------------------------------
# Processes the current language zone. Although the tectogrammatical tree is
# our primary source of information, we may have to reach to the analytical and
# morphological annotation, too.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $orig = $self->_orig_data();
    my $record = shift(@{$orig});
    if(!defined($record))
    {
        log_fatal("Original data ended prematurely");
    }
    elsif($record->{type} ne 'sentence')
    {
        log_fatal("Original data out of sync: expected new sentence");
    }
    $zone->set_sentence($record->{text});
    my $aroot = $zone->get_tree('a');
    my @nodes = $aroot->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        my $record = shift(@{$orig});
        if(!defined($record))
        {
            log_fatal("Original data ended prematurely");
        }
        elsif($record->{type} ne 'token')
        {
            log_fatal("Original data out of sync: expected new token");
        }
        elsif($record->{form} ne $node->form())
        {
            log_fatal("Original data out of sync: original token = '$record->{form}', actual token = '".$node->form()."'");
        }
        $node->set_no_space_after($record->{no_space_after});
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::RestoreNoSpaceAfter

=head1 DESCRIPTION

Before reading the main input (i.e., during initialization), this block reads
a CoNLL-U file with an older version of the data that will be processed later.
The older version contains correctly detokenized sentence text, and the
SpaceAfter=No attribute of each node. Only this and the word forms matter, the
rest of the CoNLL-U file is ignored. The CoNLL-U file should not contain multi-
word tokens.

The block then processes a-trees of the main document stream. The sentences and
word forms must exactly match the CoNLL-U file that we read earlier, only the
spaces between tokens may be different and the block will restore them following
the data from the CoNLL-U file.

This is an ad-hoc block to fix data for the CoNLL MRP 2020 shared task. The data
was first preprocessed (tokenized, tagged, analytically and tectogrammatically
parsed) in Treex, then human annotators checked the main part of tectogrammatical
annotation. Then it was prepared by Jiří Mírovský for other annotators who would
annotate coreference and some other missing phenomena. Unfortunately, the Treex
block that exports the data to the PEDT format loses the no_space_after
attribute, so we must restore it now.

Sample usage:

C<treex -Len Read::Treex from='!damaged/*.treex.gz' W2W::RestoreNoSpaceAfter origconllu=original.conllu Write::Treex path=fixed>

=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=back

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2020 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

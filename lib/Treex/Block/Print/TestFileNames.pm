package Treex::Block::Print::TestFileNames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _stat => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $stat = $self->_stat();
    my $file = $node->get_document()->full_filename();
    # Remember the number of tokens in each file.
    $stat->{$file}++;
}

sub process_end
{
    my $self = shift;
    my $stat = $self->_stat();
    my @files = sort(keys(%{$stat}));
    my $n = 0;
    my $ntest = 0;
    my $nfiles = @files;
    my $ntestfiles = 0;
    foreach my $file (@files)
    {
        my $nfile = $stat->{$file};
        if($ntest*10<$n)
        {
            print("$file\t$nfile\n");
            $ntest += $nfile;
            $ntestfiles++;
        }
        $n += $nfile;
    }
    printf("TOTAL $nfiles files, TEST $ntestfiles files (%d %%)\n", $ntestfiles/$nfiles*100) if($nfiles);
    printf("TOTAL $n tokens, TEST $ntest tokens (%d %%)\n", $ntest/$n*100) if($n);
}

1;

=head1 NAME

Treex::Block::Print::TestFileNames

=head1 DESCRIPTION

Suggests approximately every tenth document as test data.
An even sampling of test documents from the corpus will ensure a balanced distribution of domains in both training and test.
The block counts tokens in each document and attempts to get 10% of all tokens as test.

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

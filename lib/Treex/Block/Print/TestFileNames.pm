package Treex::Block::Print::TestFileNames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has dev => ( is => 'ro', isa => 'Bool', default => 0, documentation => 'Should we also suggest development data set? Default: only training/test.' );
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
    my $ndev = 0;
    my $ntest = 0;
    my $nfiles = @files;
    my $ndevfiles = 0;
    my $ntestfiles = 0;
    foreach my $file (@files)
    {
        my $nfile = $stat->{$file};
        if($self->need_more_dev($ndev, $n))
        {
            print("DEVFILE\t$file\t$nfile\n");
            $ndev += $nfile;
            $ndevfiles++;
        }
        elsif($self->need_more_test($ntest, $n))
        {
            print("TESTFILE\t$file\t$nfile\n");
            $ntest += $nfile;
            $ntestfiles++;
        }
        $n += $nfile;
    }
    printf("TOTAL $nfiles files, DEV $ndevfiles files (%d %%), TEST $ntestfiles files (%d %%)\n", $ndevfiles/$nfiles*100, $ntestfiles/$nfiles*100) if($nfiles);
    printf("TOTAL $n tokens, DEV $ndev tokens (%d %%), TEST $ntest tokens (%d %%)\n", $ndev/$n*100, $ntest/$n*100) if($n);
}

sub need_more_dev
{
    my $self = shift;
    my $ndev = shift; # total dev tokens so far
    my $n = shift; # total tokens so far
    return $self->dev() && ($ndev * 10 < $n);
}

sub need_more_test
{
    my $self = shift;
    my $ntest = shift; # total test tokens so far
    my $n = shift; # total tokens so far
    return $ntest * 10 < $n;
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

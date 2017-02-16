package Treex::Block::HamleDT::AR::TestFileNames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has dev => ( is => 'ro', isa => 'Bool', default => 0, documentation => 'Should we also suggest development data set? Default: only training/test.' );
has _stat => ( is => 'ro', default => sub { {} } );
has dima => ( is => 'ro', isa => 'String', required => 1, documentation => 'Path to the tab-separated text file from Dima Taji.' );
has _list_from_dima_taji => ( is => 'ro', isa => 'HashRef', builder => '_read_list_from_dima', lazy_build => 1 );

sub _read_list_from_dima
{
    my $self = shift;
    my $dima = $self->dima();
    log_fatal("Unknown path to the file list form Dima") if(!defined($dima));
    open(DIMA, $dima) or log_fatal("Cannot read '$dima': $!");
    # DIMA: tab-separated values exported from Dima's Excel file. First row contains column headers.
    my @headers;
    my @table;
    my %division;
    while(<DIMA>)
    {
        s/\r?\n$//;
        my @row = split(/\t/, $_);
        if(scalar(@headers)==0)
        {
            @headers = @row;
        }
        else
        {
            my %record;
            for(my $i = 0; $i <= $#row; $i++)
            {
                $record{$headers[$i]} = $row[$i];
            }
            push(@table, \%record);
            # Hash section names (Train, Dev, Test) for document ids.
            $division{$record{'Document ID in PAUDT'}} = lc($record{'NYUADUDT division'});
        }
    }
    close(DIMA);
    return \%division;
}

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
    my $div = $self->_list_from_dima_taji();
    foreach my $file (@files)
    {
        my $nfile = $stat->{$file};
        if(exists($div->{$file}))
        {
            if($self->dev() && $div->{$file} eq 'dev')
            {
                print("DEVFILE\t$file\t$nfile\n");
                $ndev += $nfile;
                $ndevfiles++;
            }
            elsif($div->{$file} eq 'test')
            {
                print("TESTFILE\t$file\t$nfile\n");
                $ntest += $nfile;
                $ntestfiles++;
            }
        }
        elsif($self->need_more_dev($ndev, $n))
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

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::AR::TestFileNames

=head1 DESCRIPTION

This block is based on Print::TestFileNames but it is not formally declared as
its subclass. It reads a list of files that are predetermined for a particular
division (train, dev or test). For the remaining files applies the default
behavior:

Suggests approximately every tenth document as test data.
An even sampling of test documents from the corpus will ensure a balanced distribution of domains in both training and test.
The block counts tokens in each document and attempts to get 10% of all tokens as test.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

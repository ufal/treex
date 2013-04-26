package Treex::Block::Print::TokenStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Missing required parameter 'language'"; }

# Storage that accummulates information over all documents. Print summary in process_end().
has _stats => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $stat = $self->_stats();
    # Investigate tokenization rules.
    # Look for unusual tokens.
    my $form = $node->form();
    if(defined($form) && $form !~ m/^\pL+$/ && $form !~ m/^\pN+$/ && $form !~ m/^(\.|,|;|:|\?|!|\(|\)|")$/)
    {
        $stat->{forms}{$form}{n}++;
        if($stat->{forms}{$form}{n}==1)
        {
            $stat->{forms}{$form}{example} = $node->get_position();
        }
    }
}

sub process_end
{
    my $self = shift;
    my $stat = $self->_stats();
    my $fh = $self->_file_handle();
    my @forms = sort(keys(%{$stat->{forms}}));
    foreach my $form (@forms)
    {
        my $n = $stat->{forms}{$form}{n};
        my $example = $stat->{forms}{$form}{example};
        print {$fh} ("$form\t$n\t$example\n");
    }
}

1;

=head1 NAME

Treex::Block::Print::TokenStats

=head1 DESCRIPTION

This block serves investigation of various tokenization schemes used in the treebanks.

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

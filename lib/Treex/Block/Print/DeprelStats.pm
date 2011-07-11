package Treex::Block::Print::DeprelStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _deprelset => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $deprelset = $self->_deprelset();
    $deprelset->{$anode->conll_deprel()}++;
}

sub DEMOLISH
{
    my $self = shift;
    my $deprelset = $self->_deprelset();
    my $n_types = 0;
    my $n_tokens = 0;
    foreach my $tag (sort(keys(%{$deprelset})))
    {
        my $freq = $deprelset->{$tag};
        print {$self->_file_handle()} ("$tag\t$freq\n");
        $n_types++;
        $n_tokens += $freq;
    }
    print {$self->_file_handle()} ("TOTAL $n_types TAG TYPES FOR $n_tokens TOKENS\n");
}

1;

=head1 NAME

Treex::Block::Print::DeprelStats

=head1 DESCRIPTION

Lists all encountered C<conll/deprel> tags with frequencies.

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::Print::MweStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _deprelset => ( is => 'ro', default => sub { {} } );
has _deprelex  => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self = shift;
    my $anode = shift;
    #my $deprelset = $self->_deprelset();
    #my $deprelex  = $self->_deprelex();
    my @children = $anode->get_children({'ordered' => 1});
    my @mwe = grep {$_->deprel() eq 'mwe'} (@children);
    if(@mwe)
    {
        unshift(@mwe, $anode);
        print(lc(join(' ', map {$_->form()} (@mwe))), "\t", join(' ', map {$_->tag()} (@mwe)), "\t", $anode->deprel(), "\n");
    }
}

# A process_end() method could be used to summarize statistics that we collect as we read.
# However, when running on the cluster, it is better to print the individual events and count them afterwards,
# using a much simpler script.
sub process_end_BLOCKED
{
    my $self      = shift;
    my $deprelset = $self->_deprelset();
    my $deprelex  = $self->_deprelex();
    my $n_types   = 0;
    my $n_tokens  = 0;
    foreach my $tag ( keys( %{$deprelset} ) )
    {
        $n_types++;
        $n_tokens += $deprelset->{$tag};
    }
    foreach my $tag ( sort( keys( %{$deprelset} ) ) )
    {
        my $freq    = $deprelset->{$tag};
        my $relfreq = $n_tokens ? $freq/$n_tokens : 0;
        my $example = $deprelex->{$tag};
        printf { $self->_file_handle() } ("$tag\t$freq\t%.5f\t$example\n", $relfreq);
    }
    print { $self->_file_handle() } ("TOTAL $n_types TAG TYPES FOR $n_tokens TOKENS\n");
}

1;

=head1 NAME

Treex::Block::Print::MweStats

=head1 DESCRIPTION

Lists all encountered multi-word expressions (words connected using the C<mwe> relation).
Statistics can be collected afterwards.

=cut

# Copyright 2016 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

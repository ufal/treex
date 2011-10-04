package Treex::Block::Print::CoApAfunStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _deprelset => ( is => 'ro', default => sub { {} } );
has _deprelex  => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self      = shift;
    my $anode     = shift;
    my $deprelset = $self->_deprelset();
    my $deprelex  = $self->_deprelex();
    if(defined($anode->afun()) && $anode->afun() =~ m/^(Coord|Apos)$/)
    {
        my @involved = map {defined($_->afun()) ? $_->afun() : ''} ($anode->get_children({'ordered' => 1, 'add_self' => 1}));
        my @pattern = @involved;
        # Exclude delimiters from the pattern.
        #@pattern = grep {$_ !~ m/^Aux[GXY]$/} (@involved);
        my $pattern = join(' ', @pattern);
        $deprelset->{$pattern}++;
    }
}

sub process_end
{
    my $self      = shift;
    my $deprelset = $self->_deprelset();
    my $deprelex  = $self->_deprelex();
    my $n_types   = 0;
    my $n_tokens  = 0;
    foreach my $pattern (sort {$deprelset->{$b} <=> $deprelset->{$a}} (keys(%{$deprelset})))
    {
        my $freq    = $deprelset->{$pattern};
        print { $self->_file_handle() } ("$pattern\t$freq\n");
        $n_types++;
        $n_tokens += $freq;
    }
    print { $self->_file_handle() } ("TOTAL $n_types PATTERN TYPES FOR $n_tokens STRUCTURES\n");
}

1;

=head1 NAME

Treex::Block::Print::CoApAfunStats

=head1 DESCRIPTION

Collects afun patterns of Coord/Apos children.
Used to find solution to treebanks where coordination members are not explicitly distinguished from shared modifiers.

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

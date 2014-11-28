package Treex::Tool::Probe;

use Treex::Core::Common;

use strict;
use warnings;
use Time::HiRes qw(time);

my %time_begin = ();
my %time_total = ();

=head2 begin($name)

Beginning of event C$<name>.

=cut

sub begin {
    my $name = shift;
    $time_begin{$name} = time();

    return;
}

=head2 end(name)

End of event C$<name>.

=cut

sub end {
    my $name = shift;
    if ( ! defined($time_begin{$name}) ) {
        return;
    }

    $time_total{$name}{'time'} += time() - $time_begin{$name};
    $time_total{$name}{'count'} += 1;

    delete($time_begin{$name});

    return;
}

=head2 get_stats

Returns measured statistics in format:
{ name1 => { 'time' => ..., 'count' => ...}, name2 => ...}

=cut

sub get_stats
{
    return %time_total;
}

=head2 print_stats

Prints out measured statistics in format:
name1   time1   count1
name2   time2   count2

=cut

sub print_stats
{
    log_info "Probe Results:";
    for my $name (sort keys %time_total) {
        log_info sprintf("Probe\t%30s\t%10.3f\t%d",
            $name,
            $time_total{$name}{'time'},
            $time_total{$name}{'count'}
        );
    }

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Probe

=head1 DESCRIPTION

A module for measuring time consumed.

=head1 AUTHORS

Martin Majlis <majlis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


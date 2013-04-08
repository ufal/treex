package Treex::Tool::NamedEnt::Features::Containers;

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::NamedEnt::Features::Containers - Package for extracting
named entity container patterns

=head1 SYNOPSIS

  use Treex::Tool::NamedEnt::Features::Containers;

  @containers = get_container_patterns($sentence, $threshold);

  for $container (@containers) {
      $pattern = $container->{pattern};
      $label   = $container->{label};
  }

=head1 DESCRIPTION

This package exports method C<get_container_patterns> as described
above. It is used to perform container pattern extraction for named
entity container classification.

=head1 AUTHOR

Jindra Helcl <jindra.helcl@gmail.com>, Petr Jankovský
<jankovskyp@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw/get_container_patterns/;

sub get_container_patterns {
    my ($sentence, $threshold) = @_;

    # struktura entity = entity->{start, end, type};

    my @words = @{$sentence->{words}};
    my @namedents = @{$sentence->{namedents}};

    my %containers;

    for my $ne (grep { $_->{type} =~ /^[APCT]$/ } @namedents) {
        $containers{$ne->{start}}{$ne->{end}} = $ne;
    }

    my @ents = map {0} @words;

    for my $ne (  sort { $a->{end} - $a->{start} <=> $b->{end} - $b->{start} }
                      grep { $_->{type} !~ /^[APCT]$/ }
                          @namedents ) {

        my $start = $ne->{start};
        my $end = $ne->{end};
        my $type = $ne->{type};

        for my $pos ($start .. $end) {
            $ents[$pos-1] = $type;
        }
    }

    my @patterns;

    for my $start (0..$#words) {
        for my $end ($start..$#words) {

	    my $length = $end - $start;
	    next if $threshold > 0 and $threshold <= $length;

            my $str = join " ", @ents[$start..$end];
            my $label = 0;

            if (defined $containers{$start+1}) {
                $label = defined $containers{$start+1}{$end+1} ? $containers{$start+1}{$end+1}{type} : 0;
            }

            push @patterns, {pattern=>$str, label=>$label};
        }
    }
    return @patterns;
}


1;

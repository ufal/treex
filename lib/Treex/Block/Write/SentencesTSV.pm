package Treex::Block::Write::SentencesTSV;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.txt' );

has 'zones' => (
    is => 'ro',
    required => 1,
    documentation => 'comma-or-space separated zone labels to be printed, e.g. "en_src,cs_tst"',
);

has 'strict' => (
    is => 'ro',
    default=>1,
    documentation => 'fail if any of the specified zones is missing',
);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my @columns;
    foreach my $zone_label (split /[, ]/,  $self->zones){
        if ($zone_label eq 'BUNDLE_ID'){
            push @columns, $bundle->id;
        } else {
            my ($language, $selector) = split /_/, $zone_label;
            my $zone = $bundle->get_zone($language, $selector);
            if (!defined $zone) {
                my $msg = $bundle->id . " does not have zone $zone_label";
                log_fatal($msg) if $self->strict;
                log_warn($msg);
                push @columns, '';
            } else{
                push @columns, $zone->sentence;
            }
        }
    }
    say { $self->_file_handle } join "\t", @columns;
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::SentencesTSV

=head1 SYNOPSIS

 Write::SentencesTSV zone=BUNDLE_ID,en_src,cs_tst

=head1 DESCRIPTION

Document writer for plain text format multiple sentences per line, separated by tabs.

=head1 ATTRIBUTES

=over

=item zones

Comma-or-space separated zone labels to be printed.
Special label BUNDLE_ID results in printing bundle id.

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

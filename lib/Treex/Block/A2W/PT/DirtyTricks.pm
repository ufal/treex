package Treex::Block::A2W::PT::DirtyTricks;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;

    $sentence =~ s/``\s*/“/g; # Isto ainda é necessario?
    $sentence =~ s/\s*''/”/g;

    $sentence =~ s/“//g;
    $sentence =~ s/”//g;

    $zone->set_sentence($sentence);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::PT::DirtyTricks

=head1 DESCRIPTION

This is the place for temporary regex-based hacks.

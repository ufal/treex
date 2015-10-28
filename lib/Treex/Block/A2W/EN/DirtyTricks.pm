package Treex::Block::A2W::EN::DirtyTricks;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;

    $sentence =~ s/``\s*/“/g;
    $sentence =~ s/\s*''/”/g;
    $sentence =~ s/( |^)I\s+I( |$)/\1I\2/g;

    $zone->set_sentence($sentence);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::EN::DirtyTricks

=head1 DESCRIPTION

This is the place for temporary regex-based hacks.

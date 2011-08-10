package Treex::Block::Print::Frames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub build_language { return log_fatal "Parameter 'language' must be given"; }
has print_frames  => ( is => 'ro', isa => 'Bool', default => 0 );
has print_summary => ( is => 'ro', isa => 'Bool', default => 1 );

my %frames;
my %lemmas;
my $nodes;

sub process_anode {
    my ( $self, $anode ) = @_;
    return if !$self->should_process($anode);

    $nodes++;
    my $lemma = $anode->lemma;
    my $frame =
        join ' ',
        map { $self->frame_element($_) }
        grep {defined} $anode->get_children( { ordered => 1 } );
    if ( $self->print_frames ) {
        print "$lemma\t$frame\n";
    }
    $frames{$lemma}{$frame}++;
    $lemmas{$lemma}++;
    return;
}

sub should_process {
    my ( $self, $anode ) = @_;
    return $anode->tag =~ /^V/;
}

sub frame_element {
    my ( $self, $anode ) = @_;
    return $anode->tag;
}

END {
    for my $lemma ( sort { $lemmas{$b} <=> $lemmas{$a} } keys %lemmas ) {
        my $freq          = $lemmas{$lemma};
        my $unique_frames = keys %{ $frames{$lemma} };
        print "$freq\t$unique_frames\t$lemma\n";
    }
}

1;

=head1 NAME

Treex::Block::Print::Frames

=head1 DESCRIPTION

Prints statistics on so-called full-valency frames (all children of a node).

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

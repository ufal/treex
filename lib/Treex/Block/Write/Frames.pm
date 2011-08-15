package Treex::Block::Write::Frames;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub build_language { return log_fatal "Parameter 'language' must be given"; }
has print_frames => (is=>'ro', isa=>'Bool', default=>1);
has print_summary => (is=>'ro', isa=>'Bool', default=>1);


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
        map {$self->frame_element($_)}
		grep {defined} $anode->get_children({ordered=>1});
    if ($self->print_frames){
        print "$lemma\t$frame\n";
    }
    $frames{$lemma}{$frame}++;
    $lemmas{$lemma}++;
    return;
}

sub should_process {
	my ( $self, $anode ) = @_;
	return 1;
}

sub frame_element {
	my ( $self, $anode ) = @_;
	return $anode->tag;
}

END {
    for my $lemma (sort { $lemmas{$b} <=> $lemmas{$a} } keys %lemmas){
    }
    for my $frame ( sort { $frames{$b} <=> $frames{$a} } keys %frames ) {
        my ($lemma) = $frame =~ /^([^\t]+)\t/; 
        my $frame_freq = $frames{$frame};
        my $lemma_freq = $lemmas{$lemma};
        print "$frame_freq\t$lemma_freq\t$frame\n";
    }
}

1;

=head1 NAME

Treex::Block::Write::Frames

=head1 DESCRIPTION

Prints probabilities of edge lengths (measured in words).

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

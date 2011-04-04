package Treex::Block::A2W::EN::DeleteTracesFromSentence;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has encoding => (
    is            => 'ro',
    default       => 'utf8',
    documentation => 'Output encoding. By default utf8.',
);


sub process_atree {
    my ( $self, $a_root ) = @_;
    my $bundle = $a_root->get_bundle;
    my @nodes = $a_root->get_descendants({ordered => 1});
    my @form = map {$_->form} @nodes;
    my @no_space_after = map {$_->no_space_after} @nodes;
    my @tag = map {$_->tag} @nodes;
    my $sentence = '';
    foreach my $i (0 .. $#form) {
        if ($tag[$i] ne '-NONE-') {
            $sentence .= ' ' if $i > 0 && !$no_space_after[$i - 1];
            $sentence .= $form[$i];
        }
    }
    $a_root->get_zone->set_sentence($sentence);
}

1;

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

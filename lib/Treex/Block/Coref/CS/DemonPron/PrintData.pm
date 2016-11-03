package Treex::Block::Coref::CS::DemonPron::PrintData;
use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/none/;
extends 'Treex::Block::Coref::PrintData';
with 'Treex::Block::Coref::CS::DemonPron::Base';

override 'losses_for_special_classes' => sub {
    my ($self, $anaph, @ante_cands) = @_;
    my @losses = ();
    my $coref_spec = $anaph->wild->{gold_coref_special} // "";
    unshift @losses, ( $coref_spec =~ /e/ ? 0 : 1 );
    unshift @losses, ( $coref_spec =~ /s/ ? 0 : 1 );
    unshift @losses, ( (!@ante_cands && none {$_ == 0} @losses) ? 0 : 1 );
    return @losses;
};

1;
#TODO add documentation

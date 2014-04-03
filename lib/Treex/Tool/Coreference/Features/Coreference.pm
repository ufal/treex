package Treex::Tool::Coreference::Features::Coreference;

use Moose;
use Treex::Core::Common;

use List::MoreUtils qw/any/;

with 'Treex::Tool::Coreference::CorefFeatures';

sub _is_coref {
    my ($anaph, $cand) = @_;
    my @antecs = $anaph->get_coref_chain;
    push @antecs, map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ? $_->children : () } @antecs;
    return any {$_ == $cand} @antecs;
}

sub _binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    
    my $feats = {};
    $feats->{is_coref} = _is_coref($anaph, $cand) ? 1 : 0;
    return $feats;
}

sub _unary_features {
    return {};
}

1;

package Treex::Tool::Coreference::AnteCandsGetter;

use Moose::Role;

requires '_select_all_cands';
requires '_split_pos_neg_cands';

sub get_candidates {
    my ($self, $anaph) = @_;

    return $self->_select_all_cands($anaph);
}

sub get_pos_neg_candidates {
    my ($self, $anaph) = @_;

    my $cands  = $self->_select_all_cands($anaph);
    my $antecs = $self->_get_antecedents($anaph);
    return $self->_split_pos_neg_cands($anaph, $cands, $antecs);
}

sub _get_antecedents {
    my ($self, $anaph) = @_;

    my $antecs = [];
    my @antes = $anaph->get_coref_chain;
    my @membs = map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ?
                        $_->children : () } @antes;
    return [ @antes, @membs ];
}

# TODO doc
1;

package Treex::Block::T2T::EN2CS::TrLNumbers;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $cs_tnode->t_lemma_origin !~ /^clone/;

    my $en_tnode = $cs_tnode->src_tnode or return;
    my $en_tlemma = $en_tnode->t_lemma();
    if (my $cs_tlemma = $self->get_translations($en_tlemma)){
        $cs_tnode->set_t_lemma($cs_tlemma);
        $cs_tnode->set_t_lemma_origin('rule-TrLNumbers');
        $cs_tnode->set_attr( 'mlayer_pos', 'C' )
    }
    return;
}

sub get_translations {
    my ($self, $en_tlemma) = @_;

    # 1st -> 1. 2nd -> 2.
    return "$1." if $en_tlemma =~ /(\d+)(st|nd|rd|th)$/;
    
    # Czech has decimal comma, not decimal point.
    # thousand separator is not a comma, but a space (ISO 31-0)
    if ( $en_tlemma =~ /^\d+(,\d\d\d)*(\.\d+)?$/ ) {
        $en_tlemma =~ s/\.(\d+)$/,$1/;           
        $en_tlemma =~ s/(\d),(\d\d\d)/$1 $2/g;  
        return $en_tlemma;
    }
    
    # forty-four -> 44
    # TODO: fourty-four -> čtyřiačtyřicet
    if ( $en_tlemma =~ /^(\p{isAlpha}+)-(\p{isAlpha}+)$/ ) {
        my $first = Treex::Tool::Lexicon::EN::number_for($1);
        my $second = Treex::Tool::Lexicon::EN::number_for($2);
        return $first + $second if $first && $second;
    }

    return;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrNumbers

Rules for translating English numbers to Czech, e.g. decimal point -> decimal comma.
An alternative to Treex::Tool::TranslationModel::Derivative::EN2CS::Numbers

=back

=cut

# Copyright 2014 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.


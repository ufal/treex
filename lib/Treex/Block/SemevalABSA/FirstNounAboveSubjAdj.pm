package Treex::Block::SemevalABSA::FirstNounAboveSubjAdj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @adjectives = grep { 
        $_->get_attr('tag') =~ m/^JJ/
        && $self->is_subjective( $_ )
    } $atree->get_descendants;
    for my $adj (@adjectives) {
        my $polarity = $self->get_polarity( $adj );
        my $parent = $adj->get_parent;
        while (1) {
            if ($parent->get_attr('tag') =~ m/^N/) {
                $self->mark_node( $parent, "sub_adj" . $polarity );
                last;
            } else {
                $parent = $parent->get_parent;
            }
        }
    }
}

1;

#  Pokud jsem hodnotici adjektivum a visim na substantivu, je toto substantivum aspekt
# 
#             Pr. A very capable RSTR kitchen.

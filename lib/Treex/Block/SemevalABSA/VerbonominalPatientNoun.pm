package Treex::Block::SemevalABSA::VerbonominalPatientNoun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @nouns = grep { 
        $_->get_attr('tag') =~ m/^N/
        && $_->get_attr('afun') eq 'Pnom'
    } $atree->get_descendants;

    for my $node (@nouns) {
        my $polarity = $self->get_polarity( $node );
        my $parent = $node;
        while (! $parent->is_root && $parent->lemma ne "be") {
            $parent = $parent->get_parent;
        }
        next if $parent->is_root;

        my @sbs = grep { $_->get_attr('afun') eq 'Sb' } $self->get_clause_descendants( $parent );

        my $total = $self->combine_polarities(
            map { $self->get_polarity( $_ ) }
            grep { $self->is_subjective( $_ ) }
            map { $self->get_clause_descendants( $_ ) } @sbs            
        );

        $self->mark_node( $node, "vbnm_patn" . $total );
    }

    return 1;
}

1;

#    Pokud jsem jmenna cast verbonominalniho predikatu a jsem substantivum,
#    jsem patiens a jsem apekt (hodnotici vyraz je v agentu).
#
#           Pr. Our favourite meal ACT is the sausage PAT.

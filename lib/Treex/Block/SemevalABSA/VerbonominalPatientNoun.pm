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
        my $parent = $node;
        while (! $parent->is_root && $parent->lemma ne "be") {
            $parent = $parent->get_parent;
        }
        next if $parent->is_root;
        my $negated = grep { $_->lemma eq 'not' } $parent->get_children;

        my @sbs = grep { $_->afun =~ m/^Sb/ } $self->get_clause_descendants( $parent );

        my @polarities = (
            map { $self->get_polarity( $_ ) }
            grep { $self->is_subjective( $_ ) }
            map { $self->get_clause_descendants( $_ ) } @sbs            
        );

        if ( @polarities ) {
            my $total = $self->combine_polarities( @polarities );
            $total = $self->switch_polarity( $total ) if $negated;
            $self->mark_node( $node, "vbnm_patn" . $total );
        }
    }

    return 1;
}

1;

#    Pokud jsem jmenna cast verbonominalniho predikatu a jsem substantivum,
#    jsem patiens a jsem apekt (hodnotici vyraz je v agentu).
#
#           Pr. Our favourite meal ACT is the sausage PAT.

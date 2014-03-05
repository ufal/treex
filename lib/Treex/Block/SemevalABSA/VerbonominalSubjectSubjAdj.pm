package Treex::Block::SemevalABSA::VerbonominalSubjectSubjAdj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @adjs = grep { 
        $_->get_attr('tag') =~ m/^JJ/
        && $_->get_attr('afun') eq 'Pnom'
        && $self->is_subjective( $_ )
    } $atree->get_descendants;

    my @predicates;

    for my $node (@adjs) {
        my $polarity = $self->get_polarity( $node );
        my $parent = $node->get_parent;
        while (! $parent->is_root ) {
            if ($parent->get_lemma eq "be") {
                push @predicates, {
                    node => $parent,
                    polarity => $polarity,
                };
            } else {
                $parent = $parent->get_parent;
            }
        }
    }

    for my $pred (@predicates) {
        my ($subj, @rest) = grep {
            $_->get_attr('afun') eq 'Sb'
        } $self->get_clause_descendants( $pred->{node} );
        if ($subj) {
            $self->mark_node( $subj, "vbnm_sb_adj" . $pred->{polarity} );
        } else {
            log_warn "No subject found for predicate: " . $pred->{node}->get_attr('id');
        }

        if (@rest) {
            log_warn "More than one subject found for predicate: " . $pred->{node}->get_attr('id');
        }
    }

    return 1;
}

1;

# Pokud jsem jmenna cast verbonominalniho predikatu a jsem hodnotici adjektivum,
# je aspektem podmet slovesa (sponove vzdy „to be“), na kterem visim. (pozor!
# sloveso nemusi byt vždy PRED – zavisle klauze!)
# 
#   Pr. The staff ACT was horrible RSTR.
# 
#     The perk was great, The fried rice is amazing. Etc.

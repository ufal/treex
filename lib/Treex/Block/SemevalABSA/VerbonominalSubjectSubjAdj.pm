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
        log_info "at node " . $node->form;
        my $polarity = $self->get_polarity( $node );
        my $parent = $node;
        while (! $parent->is_root ) {
            if ($parent->lemma eq "be") {
                my $negated = grep { $_->lemma eq 'not' } $parent->get_children;
                $polarity = $self->switch_polarity( $polarity ) if $negated;
                push @predicates, {
                    node => $parent,
                    polarity => $polarity,
                };
                log_info "found its predicate: " . $parent->id;
                last;
            } else {
                $parent = $parent->get_parent;
            }
        }
    }

    for my $pred (@predicates) {
        log_info "at predicate: " . $pred->{node}->id;
        my @subjects = grep {
            $_->afun =~ m/^Sb/
        } $self->get_clause_descendants( $pred->{node} );
        log_info "found subjects: " . scalar(@subjects);
        map { $self->mark_node( $_, "vbnm_sb_adj" . $pred->{polarity} ) } @subjects;
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

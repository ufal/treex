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
    $self->_add_following_antecs($anaph, $antecs, $anaph);
    return $antecs;
}


sub _add_following_antecs {
    my ($self, $jnode, $p_antecs, $first_anaph) = @_;       
    my @new_antecs = ();
    if (defined $jnode) {
        @new_antecs = $jnode->get_coref_nodes;
    }

    if (@new_antecs) {
        foreach my $node (@new_antecs) {                                             
            if ($node->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/) {
                foreach my $member ($node->children) {
                    push @$p_antecs, $member;
                }
            }
            if ( !(grep {$_ == $node} @$p_antecs) && ($node ne $first_anaph)) {
                push @$p_antecs, $node;                                                       
                $self->_add_following_antecs($node, $p_antecs, $first_anaph);
            }
            else {
#               print TredMacro::FileName() . "##$node->{aca_sentnum}.$node->{deepord}\n";
            }
        }       
    }           
}

# TODO doc
1;

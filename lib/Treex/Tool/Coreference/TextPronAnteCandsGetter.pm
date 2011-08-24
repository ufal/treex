package Treex::Tool::Coreference::TextPronAnteCandsGetter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::AnteCandsGetter';

sub _select_all_cands {
    my ($self, $anaph) = @_;
    
    # current sentence
    my @sent_preceding = grep { $_->precedes($anaph) }
        $anaph->get_root->get_descendants( { ordered => 1 } );

    # previous sentence
    my $sent_num = $anaph->get_bundle->get_position;
    if ( $sent_num > 0 ) {
        my $prev_bundle = ( $anaph->get_document->get_bundles )[ $sent_num - 1 ];
        my $prev_tree   = $prev_bundle->get_tree(
            $anaph->language,
            $anaph->get_layer,
            $anaph->selector
        );
        unshift @sent_preceding, $prev_tree->get_descendants( { ordered => 1 } );
    }
    else {

        # TODO it should inform that the previous context is not complete
    }

    # semantic noun filtering
    # TODO consider removing of the noun filtering from here and possibly
    # replacing it by a separate class
    my @cands = grep { $_->gram_sempos && ($_->gram_sempos =~ /^n/) 
                    && (!$_->gram_person || ($_->gram_person !~ /1|2/)) }
        @sent_preceding;

    # reverse to ensure the closer candidates to be indexed with lower numbers
    return \@{reverse @cands};
}


# This method splits all candidates to positive and negative ones
# It returns two hashmaps of candidates indexed by their order within all
# returned candidates.
sub _split_pos_neg_cands {
    my ($self, $anaph, $cands, $antecs) = @_;

    my %ante_hash = map {$_->id => $_} @$antecs;
    
    my $pos_cand = $self->_find_positive_cand($anaph, $cands);
    my @neg_cands;
    my @pos_ords;
    my @neg_ords;

    my $ord = 1;
    foreach my $cand (@$cands) {
        if (!defined $ante_hash{$cand->id}) {
            push @neg_cands, $cand;
            push @neg_ords, $ord;
        }
        elsif ($cand == $pos_cand) {
            push @pos_ords, $ord;
        }
        $ord++;
    }

    return ( [$pos_cand], \@neg_cands, \@pos_ords, \@neg_ords );
}

sub _find_positive_cand {
    my ($self, $jnode, $cands) = @_;
    my $non_gram_ante;

    my %cands_hash = map {$_->id => $_} @$cands;
    my @antes = $jnode->get_coref_text_nodes;
    if (@antes > 0) {
        my $ante = $antes[0];
        $non_gram_ante = $self->_jump_to_non_gram_ante(
                $ante, \%cands_hash);
    }
    return $non_gram_ante;
}

# jumps to the first non-grammatical antecedent in a coreferential chain
sub _jump_to_non_gram_ante {            
    my ($self, $ante, $cands_hash) = @_;

    if ( defined $cands_hash->{$antec->id} ) {
        my @gram_antes = $ante->get_coref_gram_nodes;
        if (@gram_antes == 1) {
            return $self->_jump_to_non_gram_ante($gram_antes[0], $cands_hash);
        }
        elsif (@gram_antes > 1) {
            # co delat v pripade Adama s Evou?
            return;
        }
        else {
            return $ante;
        }
    }
    return;
}

# TODO doc

1;

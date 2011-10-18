package Treex::Tool::Coreference::CS::TextPronAnteCandsGetter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::AnteCandsGetter';

# according to rule presented in Nguy et al. (2009)
# semantic nouns from previous context of the current sentence and from
# the previous sentence
# TODO think about preparing of all candidates in advance
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
    my @reversed_cands = reverse @cands;
    return \@reversed_cands;
}


# This method splits all candidates to positive and negative ones
# It returns two hashmaps of candidates indexed by their order within all
# returned candidates.
sub _split_pos_neg_cands {
    my ($self, $anaph, $cands, $antecs) = @_;

    my %ante_hash = map {$_->id => $_} @$antecs;
    
    my $pos_cands = $self->_find_positive_cands($anaph, $cands);
    my $neg_cands = [];
    my $pos_ords = [];
    my $neg_ords = [];

    my $ord = 1;
    foreach my $cand (@$cands) {
        if (!defined $ante_hash{$cand->id}) {
            push @$neg_cands, $cand;
            push @$neg_ords, $ord;
        }
        elsif (grep {$_ == $cand} @$pos_cands) {
            push @$pos_ords, $ord;
        }
        $ord++;
    }
    return ( $pos_cands, $neg_cands, $pos_ords, $neg_ords );
}

sub _find_positive_cands {
    my ($self, $jnode, $cands) = @_;
    my $non_gram_ante;

    my %cands_hash = map {$_->id => $_} @$cands;
    my @antes = $jnode->get_coref_text_nodes;

# TODO to comply with the results of Linh et al. (2009), this do not handle a
# case when an anphor points to more than ones antecedents, e.g.
# t-cmpr9413-032-p3s2w4 (nimi) -> (pozornost, dar)
    if (@antes == 1) {
        my $ante = $antes[0];

# TODO for debugging reasons to accord with the data of Linh et al. (2009). This should be
# cancelled afterwards
        if ($jnode->wild->{doc_ord} < $ante->wild->{doc_ord}) {
            return [];
        }

        $non_gram_ante = $self->_jump_to_non_gram_ante(
                $ante, \%cands_hash);
    }
    return [] if (!defined $non_gram_ante);
    return [ $non_gram_ante ];
}

# jumps to the first non-grammatical antecedent in a coreferential chain which
# is contained in the list of candidates
sub _jump_to_non_gram_ante {            
    my ($self, $ante, $cands_hash) = @_;

    my @gram_antes = $ante->get_coref_gram_nodes;
    
    #while  (!defined $cands_hash->{$ante->id}) {

# TODO to comply with the results of Linh et al. (2009)
    while  (@gram_antes == 1) {

# TODO to comply with the results of Linh et al. (2009), a true antecedent
# must be a semantic noun, moreover all members of the same coreferential
# chain between the anaphor and the antecedent must be semantic nouns as well
        return undef 
            if (!defined $ante->gram_sempos || ($ante->gram_sempos !~ /^n/));

        $ante = $gram_antes[0];
        @gram_antes = $ante->get_coref_gram_nodes;
    }
    
    if (@gram_antes > 1) {
        # co delat v pripade Adama s Evou?
        return undef;
    }
    elsif (!defined $cands_hash->{$ante->id}) {
        return undef;
    }
    
    return $ante;
}

# TODO doc

1;

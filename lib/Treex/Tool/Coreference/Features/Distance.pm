##################################################
########### THIS MODULE IS NEVER USED ############
############### SHOULD BE REMOVED ################
##################################################
package Treex::Tool::Coreference::Features::Distance;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::CorefFeatures';

sub binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    
    my $coref_features = {};
    
    ###########################
    #   Distance:
    #   4x num: sentence distance, clause distance, file deepord distance, candidate's order
    $coref_features->{c_sent_dist} =
        $anaph->get_bundle->get_position - $cand->get_bundle->get_position;
    $coref_features->{c_clause_dist} = _categorize(
        $anaph->wild->{aca_clausenum} - $cand->wild->{aca_clausenum}, 
        [-2, -1, 0, 1, 2, 3, 7]
    );
    $coref_features->{c_file_deepord_dist} = _categorize(
        $anaph->wild->{doc_ord} - $cand->wild->{doc_ord},
        [1, 2, 3, 6, 15, 25, 40, 50]
    );
    $coref_features->{c_cand_ord} = _categorize(
        $candord,
        [1, 2, 3, 5, 8, 11, 17, 22]
    );
    #$coref_features->{c_cand_ord} = $candord;

    # a feature from (Charniak and Elsner, 2009)
    # this antecedent position depends on the location of antecedent, thus placed among binary features
    $coref_features->{c_cand_loc_buck} = $self->_ante_loc_buck($anaph, $cand, $coref_features->{c_sent_dist});

    return $coref_features;
}

sub unary_features {
    my ($self, $node, $type) = @_;
    
    my $coref_features = {};
    
    if ($type eq 'anaph') {
        $coref_features->{c_anaph_sentord} = _categorize(
            $node->get_root->wild->{czeng_sentord},
            [0, 1, 2, 3]
        );
        
        # a feature from (Charniak and Elsner, 2009)
        $coref_features->{c_anaph_loc_buck} = $self->_anaph_loc_buck($node);
    }
    
    return $coref_features;
}

sub _ante_loc_buck {
    my ($self, $anaph, $cand, $sent_dist) = @_;

    my $pos = $cand->ord;
    if ($sent_dist == 0) {
        $pos = $anaph->ord - $cand->ord;
    }
    return _categorize( $pos, [0, 3, 5, 9, 17, 33] );
}

sub _anaph_loc_buck {
    my ($self, $anaph) = @_;
    return _categorize( $anaph->ord, [0, 3, 5, 9] );
}


1;

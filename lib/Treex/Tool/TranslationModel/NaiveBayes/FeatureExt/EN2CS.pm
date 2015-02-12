package Treex::Tool::TranslationModel::NaiveBayes::FeatureExt::EN2CS;

use strict;
use warnings;

use Treex::Tool::TranslationModel::Features::Standard;
use Treex::Tool::TranslationModel::MaxEnt::FeatureExt::EN2CS;
use Data::Dumper;

my $features_for_version = {
    '0.9' => [
    'formeme_sd',
    'formeme_sg',
    'next_node_tlemma',
    'number_sd',
    'number_sg',
    'position',
    'prev_node_tlemma',
    'sempos_sd',
    'sempos_sg',
    'short_sempos_sg',
    'tag_sd',
    'tag_sg',
    'tlemma_sd',
    'tlemma_sg'
    ],
    '1.0' => [
    'lemma',
    'formeme',
    'tag',
    'person',
    'number',
    'short_sempos',
#    'sempos',
    'capitalized',
    'parent_formeme',
#    'parent_precedes_parent',
    'parent_tag',
    'parent_lemma',
#    'parent_capitalized',
#    'precedes_parent', 
#    'parent_sempos',
#    'parent_number',
#    'parent_short_sempos',
    'next_lemma',
    'prev_lemma',
    
    
#    'degcmp',
#    'voice',
#   'negation',
#    'tense',
#    'precedes_parent',
#    'parent_voice',
#    'parent_tense',
#    'has_left_child',
#    'has_right_child',
    
    
#    'precedes_parent', 
#    'parent_sempos',
#    'parent_number',
#    'parent_short_sempos',
#    'is_member',
#    'parent_is_member'        
    ]    
};



sub features_from_src_tnode {
    my ($T_sd, $version) = @_; # (t)-node - (s)ource side, (d)ependent 

    my ($T_sg) = $T_sd->get_eparents({or_topological=>1}); # governing

    my $A_sd = $T_sd->get_lex_anode;

    if ( defined $A_sd ) {
        my $features;
        if ( $version eq "1.0" ) {
            $features = Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode($T_sd);
        } else {
            $features = Treex::Tool::TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode($T_sd);
            #print STDERR Data::Dumper->Dump([$features]);
        }

        my %res_features = ();
        for my $f (@{$features_for_version->{$version}} ) {
            if ( defined($features->{$f}) ) {
                $res_features{$f . '__' . lc($features->{$f}) } = 1;
            }
        }

        return \%res_features;
    }
    return;
}

1;

package Treex::Tool::SRLParser::FeatureExtractor;

use Moose;
use Treex::Core::Common;

has 'feature_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

has 'value_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => '/',
);

has 'debug_printing_mode' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'empty_sign' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_',
);

sub extract_features() {
    my ( $self, $predicate, $depword ) = @_; 

    my @features;

    ### Features from Che & spol. ###
    
    # ChildrenPOS
    # ChildrenPOSNoDup
    # ConstituentPOSPattern
    # ConstituentPOSPattern+DepRelation
    # ConstituentPOSPattern+DepwordLemma
    # ConstituentPOSPattern+HeadwordLemma
    # DepRelation
    # DepRelation+DepwordLemma
    # DepRelation+HeadwordLemma
    # DepRelation+HeadwordLemma+DepwordLemma
    # Depword
    push @features, $self->_make_feature('Depword', $depword->form);
    # DepwordLemma
    push @features, $self->_make_feature('DepwordLemma', $depword->lemma);
    # DepwordLemma+RelationPath
    # DepwordPOS
    # DepwordPOS+HeadwordPOS
    # DownPathLength
    # FirstLemma
    # FirstPOS
    # FirstPOS+DepwordPOS
    # HeadwordLemma
    # HeadwordLemma+RelationPath
    # HeadwordPOS
    # LastLemma
    # LastPOS
    # Path
    # Path+RelationPath
    # PathLength
    # PFEATSplit
    # PositionWithPredicate
    # Predicate
    push @features, $self->_make_feature('Predicate', $predicate->form);
    # Predicate+PredicateFamilyship
    # PredicateLemma
    push @features, $self->_make_feature('PredicateLemma', $predicate->lemma);
    # PredicateLemma+PredicateFamilyship
    # PredicateSense
    # PredicateSense+DepRelation
    # PredicateSense+DepwordLemma
    # PredicateSense+DepwordPOS
    # RelationPath
    # SiblingsRELNoDup
    # UpPath
    # UpPathLength
    # UpRelationPath+HeadwordLemma
    
    ### My features ###

    # PredicatePOS
    # DepwordFeat
    # PredicateFeat
    # Distance
    # PositionToPredicate
    # PredicatePosition
    # DepwordPosition
    # PredicateHeadword
    # PredicateHeadword
    # PredicateHeadwordPOS
    # PredicateHeadwordLemma
    # DepwordConstituentFirstWord
    # DepwordConstituentFirstPOS
    # DepwordConstituentFirstLemma
    # DepwordConstituentLastWord
    # DepwordConstituentLastPOS
    # DepwordConstituentLastLemma
    # IsInFrame
    # Frame
    
    return join($self->feature_delim, @features);
}

sub _make_feature() {
    my ( $self, $name, @values ) = @_;

    return $name . $self->value_delim . join($self->value_delim, @values)
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::SRLParser::FeatureExtractor

=head1 SYNOPSIS

my $feature_extractor = Treex::Tool::SRLParser::FeatureExtractor->new();
    
my @a_nodes = $a_root->get_descendants;
        
foreach my $predicate_candidate (@a_nodes) {

    foreach my $depword_candidate (@a_nodes) {

        print $feature_extractor->extract_features($predicate_candidate, $depword_candidate);
          
    }

}   

=head1 DESCRIPTION

Feature extractor for SRL parser according to L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>. Given a pair of two treex a-nodes, it returns a string of classification features.

=head1 PARAMETERS

=over

=item feature_delim

Delimiter between features. Default is space, because Maximum Entropy Toolkit
expects spaces between features. 

=item value_delim

Delimiter between feature values in combined features, such as
PredicatePOS+DepwordPOS. This only makes sense in debug printing mode to make
combined features readable.

=item debug_printing_mode

If true, classification feature string is printed in human readable format.
Currently, all outputs are in debug printing mode, feature encoding to ensure
smaller memory and disk usage need to be implemented.

=item empty_sign

A string for denoting empty or undefined values, such as no semantic relation
in t-tree, no syntactic relation in a-tree, empty values for features, etc.

=back

=head1 METHODS 

=over

=item $self->extract_features( $self, $predicate, $depword )

Given two treex a-nodes, a predicate candidate and a depword candidate, it
returns a string of classification features.

=back

=head1 TODO

Implement all classification features as suggested by the paper.
Currently, all outputs are in debug printing mode, feature encoding to ensure
smaller memory and disk usage needs to be implemented.

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

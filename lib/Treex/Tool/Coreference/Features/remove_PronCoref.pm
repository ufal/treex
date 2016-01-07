##################################################
########### THIS MODULE IS NEVER USED ############
############### SHOULD BE REMOVED ################
##################################################
package Treex::Tool::Coreference::PronCorefFeatures;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::CorefFeatures';


#sub _build_feature_names {
#    my ($self) = @_;
#    return log_fatal "method _build_feature_names must be overriden in " . ref($self);
#}

sub _binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my $coref_features = {};


    #   24: 8 x tag($inode, $jnode), joined
    

###########################
    #   Functional:
    
    #   4: get candidate and anaphor eparent functor and sempos
    #   2: agreement in eparent functor and sempos
	#my ($anaph_epar_lemma, $cand_epar_lemma) = map {my $epar = ($_->get_eparents)[0]; $epar->t_lemma} ($anaph, $cand);
    

    return $coref_features;
}

sub _unary_features {
    my ($self, $node, $type) = @_;

    my $coref_features = {};

    return if (($type ne 'cand') && ($type ne 'anaph'));

    #   1: anaphor's ID
    $coref_features->{$type.'_id'} = $node->get_address;

###########################
    #   Functional:
    #   2:  formeme

    
    return $coref_features;
}



1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::PronCorefFeatures

=head1 DESCRIPTION

An abstract class for features needed in personal pronoun coreference
resolution. The features extracted here should be language independent.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

#=item _build_feature_names 
#
#A list of features required for training/resolution. Without implementing 
#in a subclass it throws an exception.

=back

=head2 Already implemented

=over

=item _unary_features

It returns a hash of unary features that relate either to the anaphor or the
antecedent candidate. 

Contains just language-independent features. It should be extended by 
overriding in a subclass.

=item _binary_features 

It returns a hash of binary features that combine both the anaphor and the
antecedent candidate.

Contains just language-independent features. It should be extended by 
overriding in a subclass.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

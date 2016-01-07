package Treex::Tool::Coreference::CorefFeatures;

use Moose;
#use Moose::Util::TypeConstraints;
use Treex::Core::Common;

with 'Treex::Tool::ML::Ranker::Features';

has '+node1_label' => ( default => 'anaph' );
has '+node2_label' => ( default => 'cand' );

my $b_true = '1';
my $b_false = '-1';

sub _unary_features {
    log_warn 'Treex::Tool::Coreference::CorefFeatures is an abstract class. The _unary_features method must be implemented in a subclass.';
}
sub _binary_features {
    log_warn 'Treex::Tool::Coreference::CorefFeatures is an abstract class. The _binary_features method must be implemented in a subclass.';
}

# TODO: if not necessary for the other types, move the following methods to Coreference::PronCorefFeatures

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    if ( !$doc->get_bundles() ) {
        return;
    }
    my @trees = map { $_->get_tree( 
        $lang, 't', $sel ) }
        $doc->get_bundles;

    $self->init_doc_features_from_trees( \@trees );
}

sub init_doc_features_from_trees {
    my ($self, $trees) = @_;
    
    $self->mark_doc_clause_nums( $trees );
    $self->mark_sentord_within_blocks( $trees );
}

sub mark_sentord_within_blocks {
    my ($self, $trees) = @_;

    my @non_def = grep {!defined $_->get_bundle->attr('czeng/blockid')} @$trees;

    my $is_czeng = (@non_def > 0) ? 0 : 1;

    my $i = 0;
    my $prev_blockid = undef;
    foreach my $tree (@$trees) {
        if ($is_czeng) {
            my $block_id = $tree->get_bundle->attr('czeng/blockid');
            if (defined $prev_blockid && ($block_id ne $prev_blockid)) {
                $i = 0;
            }
            $prev_blockid = $block_id;
        }
        $tree->wild->{czeng_sentord} = $i;
        $i++;
    }
}

# TODO shouldn't be partitioning into CzEng blocks taken into account here?
sub mark_doc_clause_nums {
    my ($self, $trees) = @_;

    my $curr_clause_num = 0;
    foreach my $tree (@{$trees}) {
        my $clause_count = 0;
        
        foreach my $node ($tree->descendants ) {
            # TODO clause_number returns 0 for coap

            $node->wild->{aca_clausenum} = 
                $node->clause_number + $curr_clause_num;
            if ($node->clause_number > $clause_count) {
                $clause_count = $node->clause_number;
            }
        }
        $curr_clause_num += $clause_count;
    }
}

# TODO: move the following methods to Treex::Tool::ML::Ranker::Features and refactor

# quantization
# takes an array of numbers, which corresponds to the boundary values of
# clusters
sub _categorize {
    my ( $self, $real, $bins_rf ) = @_;
    my $retval = "-inf";
    for (@$bins_rf) {
        $retval = $_ if $real >= $_;
    }
    return $retval;
}

sub _join_feats {
    my ($self, $f1, $f2) = @_;

# TODO adjustment to accord with Linh et al. (2009)
    if (!defined $f1) {
        $f1 = "";
    }
    if (!defined $f2) {
        $f2 = "";
    }

#    if (!defined $f1 || !defined $f2) {
#        return undef;
#    }
    return $f1 . '_' . $f2;
}

sub _agree_feats {
    my ($self, $f1, $f2) = @_;

# TODO adjustment to accord with Linh et al. (2009)
    if (!defined $f1 || !defined $f2) {
        if (!defined $f1 && !defined $f2) {
            return $b_true;
        }
        else {
            return $b_false;
        }
    }

#    if (!defined $f1 || !defined $f2) {
#        return $b_false;
#    }

    my %f1_hash = map {$_ => 1} split /\|/, $f1;
    foreach my $f2_value (split /\|/, $f2) {
        return $b_true if ($f1_hash{$f2_value});
    }
    return $b_false;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::CorefFeatures

=head1 DESCRIPTION

A role for coreference features, encapsulating unary features related to 
the anaphor (candidate), antecedent candidates' as well as binary features
related to both participants of the coreference relation. If generalized more,
this role might serve as an interface to features of any binary (or binarized) 
relation.

=head1 PARAMETERS

=over

=item feature_names

Names of features that should be used for training/resolution. This list is, 
however, not obeyed inside this class. Method C<create_instances> returns all 
features that are extracted here, providing no filtering. It is a job of the 
calling method to decide whether to check the returned instances if they comply 
with the required list of features and possibly filter them.

=item format

Temporary parameter. Being assigned to one of the values C<percep> or C<unsup>, it
determines the format of a hash returned by method C<create_instances>. 

If set to C<percep> (default), the returned hash of instances is indexed by ids 
of antecedent candidates and every instance besides binary and candidate
unary features contains also anaphor unary features.

If set to C<unsup>, the returned hash of instances is on the first level divided
into  two sections, indexed by labels C<cands> and C<anaph>. The structure of the 
C<cands> section is almost the same as in the C<percep> format, just with no anaphor 
unary features included. These are stored just once in the C<anaph> section.

=back

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item _build_feature_names 

A list of features required for training/resolution.

=item _unary_features

It returns a hash of unary features that relate either to the anaphor or the
antecedent candidate.

=item _binary_features 

It returns a hash of binary features that combine both the anaphor and the
antecedent candidate.

=back

=head2 Already implemented

=over

=item anaph_feature_names

Names of features describing the anaphor (anaphor unary features).

=item nonanaph_feature_names

Names of features describing the antecedent candidate and both
the antecedent candidate and the anaphor (the union of binary and
anaphor unary features).

=item extract_anaph_features

Extracts the features describing the anaphor (anaphor unary features).

=item extract_nonanaph_features

Extracts the features describing the antecedent candidate and both
the antecedent candidate and the anaphor (the union of binary and
anaphor unary features).

=item create_instances

Returns a list of instances corresponding to antecedent candidates,
where the structure of extracted features is determined by parameter
C<format>.


=item init_doc_features

Some features require the scope of the whole document, not just the
current anaphor - antecedent candidate couple. This method provides
a place to initialize and precompute the data necessary for 
document-scope features.

Currently, method C<init_doc_features_from_trees> for language-selector
corresponding tectogrammatical trees is called.

=item init_doc_features_from_trees

The same as C<init_doc_features> method, just differs in the scope
- in this case the list of tectogrammatical trees.

Currently, in this init stage, the clause and sentence numbers 
within the whole document (or CzEng block) are set.

=item _categorize

Quantization of continuous variables into intervals.

=item _join_feats 

Produces a feature, which is a concatenation of two features.

=item _agree_feats 

Produces a feature, which is an indicator of equality of two features.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

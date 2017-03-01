package Treex::Tool::Coreference::AnteCandsGetter;

use Moose;
use Treex::Tool::Context::Sentences;
use List::MoreUtils qw/none/;
use Treex::Tool::Coreference::NodeFilter;

has 'cand_types' => ( 
    isa => 'ArrayRef[Str]',
    is => 'ro',
    required => 1,
);

has 'prev_sents_num' => (
    isa => 'Int',
    is  => 'ro',
    required => 1,
);

has 'preceding_only' => (
    isa => 'Bool',
    is => 'ro',
    default => 1,
);

has 'cands_within_czeng_blocks' => (
    isa => 'Bool',
    is  => 'ro',
    required => 1,
    default => 0,
);

has 'max_size' => (
    isa => 'Int',
    is => 'ro',
    required => 1,
    default => 0,
);

has '_node_selector' => (
    isa => 'Treex::Tool::Context::Sentences',
    is => 'ro',
    lazy => 1,
    builder => '_build_node_selector',
);

sub BUILD {
    my ($self) = @_;
    $self->_node_selector;
}

sub _build_node_selector {
    my ($self) = @_;
    return Treex::Tool::Context::Sentences->new({
        nodes_within_czeng_blocks => $self->cands_within_czeng_blocks,
    }); 
}

sub get_candidates {
    my ($self, $anaph) = @_;

    my @cands = $self->_select_all_cands($anaph);

    if ($self->max_size && (scalar @cands > $self->max_size)) {
        @cands = @cands[0 .. $self->max_size-1];
    }
    
    return @cands;
}

#sub get_pos_neg_candidates {
#    my ($self, $anaph, $relation_extractor, $args) = @_;
#
#    my @cands = $self->_select_all_cands($anaph);
#    my @is_in_relation = $relation_extractor($anaph, @cands);
#
#    if ($args->{first_only}) {
#        my ($pos_idx) = grep {$is_in_relation[$_]} 0 .. $#cands;
#        if (defined $pos_idx) {
#            splice(@cands, $pos_idx, 1);
#            splice(@is_in_relation, $pos_idx, 1);
#        }
#    }
#    return (\@cands, \@is_in_relation);
#
#    #my $antecs = $self->_get_antecedents($anaph);
#    
#    #return $self->_split_pos_neg_cands($anaph, $cands, $antecs);
#}

sub _select_all_cands {
    my ($self, $anaph) = @_;

    my @cands = $self->_node_selector->nodes_in_surroundings(
        $anaph, -$self->prev_sents_num, 0, {preceding_only => $self->preceding_only}
    );
    @cands = grep {Treex::Tool::Coreference::NodeFilter::matches($_, $self->cand_types)} @cands;
    # remove the candidates that even transitively point to the anaphor - cycle prevention
    @cands = grep {my $cand = $_; none {$_ == $anaph} $cand->get_coref_chain} @cands;
    # nearest candidates to be the first
    @cands = reverse @cands;

    return @cands;
}

#sub _get_antecedents {
#    my ($self, $anaph) = @_;
#
##     my $antecs = [];
#    return [ @antecs, @membs ];
#}
#
## This method splits all candidates to positive and negative ones
## It returns two hashmaps of candidates indexed by their order within all
## returned candidates.
#sub _split_pos_neg_cands {
#    my ($self, $anaph, $cands, $antecs) = @_;
#
#    my %ante_hash = map {$_->id => $_} @$antecs;
#    
#    my $pos_cands = $self->_find_positive_cands($anaph, $cands);
#    my $neg_cands = [];
#    my $pos_ords = [];
#    my $neg_ords = [];
#
#    if ($self->anaphor_as_candidate) {
#        if (@$pos_cands > 0) {
#            push @$neg_cands, $anaph;
#        }
#        else {
#            push @$pos_cands, $anaph;
#        }
#    }
#
#    my $ord = 1;
#    foreach my $cand (@$cands) {
#        if (!defined $ante_hash{$cand->id}) {
#            push @$neg_cands, $cand;
#            push @$neg_ords, $ord;
#        }
#        elsif (grep {$_ == $cand} @$pos_cands) {
#            push @$pos_ords, $ord;
#        }
#        $ord++;
#    }
#    return ( $pos_cands, $neg_cands, $pos_ords, $neg_ords );
#}
#
#sub _find_positive_cands {
#    my ($self, $anaph, $cands) = @_;
#    my $non_gram_ante;
#
#    my %cands_hash = map {$_->id => $_} @$cands;
#    my @antes = $anaph->get_coref_text_nodes;
#
## TODO to comply with the results of Linh et al. (2009), this do not handle a
## case when an anphor points to more than ones antecedents, e.g.
## t-cmpr9413-032-p3s2w4 (nimi) -> (pozornost, dar)
## TODO in English version the condition was as follows
## if (@antes > 0) {
#    if (@antes == 1) {
#        my $ante = $antes[0];
#
#        $non_gram_ante = $self->_jump_to_non_gram_ante(
#                $ante, \%cands_hash);
#    }
#    return [] if (!defined $non_gram_ante);
#    return [ $non_gram_ante ];
#}
#
## jumps to the first non-grammatical antecedent in a coreferential chain which
## is contained in the list of candidates
#sub _jump_to_non_gram_ante {            
#    my ($self, $ante, $cands_hash) = @_;
#
#    my @gram_antes = $ante->get_coref_gram_nodes;
#    
#    #while  (!defined $cands_hash->{$ante->id}) {
#
## TODO to comply with the results of Linh et al. (2009)
## TODO English version as follows:
##while  (@gram_antes > 0) {
#    while  (@gram_antes == 1) {
#
## TODO to comply with the results of Linh et al. (2009), a true antecedent
## must be a semantic noun, moreover all members of the same coreferential
## chain between the anaphor and the antecedent must be semantic nouns as well
## TODO was not present in the English version
#        return undef 
#            if (!defined $ante->gram_sempos || ($ante->gram_sempos !~ /^n/));
#
#        $ante = $gram_antes[0];
#        @gram_antes = $ante->get_coref_gram_nodes;
#    }
#    
## TODO 'if { ... }' was not present in the English version
#    if (@gram_antes > 1) {
#        # co delat v pripade Adama s Evou?
#        return undef;
#    }
#    elsif (!defined $cands_hash->{$ante->id}) {
#        return undef;
#    }
#    
#    return $ante;
#}

1;

# TODO adjust docs

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::AnteCandsGetter

=head1 DESCRIPTION

A role for antecedent candidates selector. It provides several methods
to obtain a list of positive and negative candidates (for training) or 
all candidates (for resolution) from the previous context. Previous 
context must be specified by the parameter C<prev_sents_num>. The filter,
which determines nodes to be included in the list of antecedent
candidates, must be specified in a sublclass.

=head1 PARAMETERS

=over

=item cand_types

Every antecedent candidate must match at least one of the type specified
by this parameter as a list.
All types specified in C<Treex::Tool::Coreference::NodeFilter> are accepted.

=item prev_sents_num

Previous context to select the candidates from. If it is set to C<n>,
it means that nodes from the same sentence prior to the anaphor and
nodes from C<n> preceding sentences are taken into consideration.
If the number of preceding sentences is lower, all of them are processed.
Default value is 1.

=item cands_within_czeng_blocks

Special parameter for CzEng documents. One CzEng document commonly
consists of several non-contiguous blocks. If this parameter is enabled,
a CzEng block (identified by the same value of the bundle's wild attribute
C<czeng/blockid>) is considered to be the largest discourse-coherent segment,
otherwise it is the whole document. Disabled by default.

=back

=head1 METHODS

=over

=item get_candidates

It select appropriate antecedent candidates from the previous context. 
Reasonable for resolving, since it does not require information about 
the true antecedent.

=item get_pos_neg_candidates 

It returns positive (the true antecendent) and negative (not an antecedent
for the actual anaphor) antecedent candidates. It requires the information
about the true antecedent to be present. Suitable for creating the training
instances.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

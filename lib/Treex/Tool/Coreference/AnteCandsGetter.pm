package Treex::Tool::Coreference::AnteCandsGetter;

use Moose::Role;

requires '_build_cand_filter';

has 'prev_sents_num' => (
    isa => 'Int',
    is  => 'ro',
    required => 1,
);

has 'anaphor_as_candidate' => (
    isa => 'Bool',
    is  => 'ro',
    required => 1,
    default => 0,
);

has 'cands_within_czeng_blocks' => (
    isa => 'Bool',
    is  => 'ro',
    required => 1,
    default => 0,
);

has '_cand_filter' => (
    isa => 'Treex::Tool::Coreference::NodeFilter',
    is  => 'ro',
    required => 1,
    builder => '_build_cand_filter',
);

sub get_candidates {
    my ($self, $anaph) = @_;

    my $cands = $self->_select_all_cands($anaph);
    if ($self->anaphor_as_candidate) {
        unshift @$cands, $anaph;
    }
    if ($self->cands_within_czeng_blocks) {
        my $block_id = $anaph->get_bundle->attr('czeng/blockid');
        if (defined $block_id) {
            my @cands_in_block = grep { 
                defined $_ && ($_->get_bundle->attr('czeng/blockid') eq $block_id)} @$cands;
            $cands = \@cands_in_block;
        }
    }
    return $cands;
}

sub get_pos_neg_candidates {
    my ($self, $anaph) = @_;

    my $cands  = $self->_select_all_cands($anaph);
    my $antecs = $self->_get_antecedents($anaph);
    return $self->_split_pos_neg_cands($anaph, $cands, $antecs);
}

sub _select_all_cands {
    my ($self, $anaph) = @_;

    my @all_cands = $self->_select_cands_in_range($anaph, $self->prev_sents_num);
    my @filtered_cands = grep {$self->_cand_filter->is_candidate( $_)} @all_cands; 

    # reverse to ensure the closer candidates to be indexed with lower numbers
    my @reversed_cands = reverse @filtered_cands;
    return \@reversed_cands;
}

# according to rule presented in Nguy et al. (2009)
# semantic nouns from previous context of the current sentence and from
# the previous sentence
# TODO think about preparing of all candidates in advance
sub _select_cands_in_range {
    my ($self, $anaph, $range) = @_;
    
    # current sentence
    my @sent_preceding = grep { $_->precedes($anaph) }
        $anaph->get_root->get_descendants( { ordered => 1 } );

    # previous sentences
    my $sent_num = $anaph->get_bundle->get_position;
    my $bottom_idx = $sent_num - $range;
    $bottom_idx = 0 if ($bottom_idx < 0);
    my $top_idx = $sent_num - 1;

    my @all_bundles = $anaph->get_document->get_bundles;
    my @prev_bundles = @all_bundles[ $bottom_idx .. $top_idx ];
    my @prev_trees   = map {
        $_->get_tree( $anaph->language, $anaph->get_layer, $anaph->selector )
    } @prev_bundles;
    foreach my $tree (@prev_trees) {
        unshift @sent_preceding, $tree->get_descendants( { ordered => 1 } );
    }

    return @sent_preceding;
}

sub _get_antecedents {
    my ($self, $anaph) = @_;

    my $antecs = [];
    my @antes = $anaph->get_coref_chain;
    my @membs = map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ?
                        $_->children : () } @antes;
    return [ @antes, @membs ];
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

    if ($self->anaphor_as_candidate) {
        if (@$pos_cands > 0) {
            push @$neg_cands, $anaph;
        }
        else {
            push @$pos_cands, $anaph;
        }
    }

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
# TODO in English version the condition was as follows
# if (@antes > 0) {
    if (@antes == 1) {
        my $ante = $antes[0];

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
# TODO English version as follows:
#while  (@gram_antes > 0) {
    while  (@gram_antes == 1) {

# TODO to comply with the results of Linh et al. (2009), a true antecedent
# must be a semantic noun, moreover all members of the same coreferential
# chain between the anaphor and the antecedent must be semantic nouns as well
# TODO was not present in the English version
        return undef 
            if (!defined $ante->gram_sempos || ($ante->gram_sempos !~ /^n/));

        $ante = $gram_antes[0];
        @gram_antes = $ante->get_coref_gram_nodes;
    }
    
# TODO 'if { ... }' was not present in the English version
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

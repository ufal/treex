package Treex::Tool::Coreference::EN::TextPronAnteCandsGetter;

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

    # antecedent candidates filtering
    my %banned_prons = map {$_ => 1} qw/i me my mine you your yours we us our ours one/;
        
    my @cands = grep {
        # grammatemes are filled        
            if (defined $_->gram_sempos) { 
            # semantic pos is noun
                ( $_->gram_sempos =~ /^n/ ) &&
            # not 1st and 2nd person
                ( !defined $_->gram_person || ( $_->gram_person !~ /1|2/ ) )
            }
        # grammatemes not provided
            else {
                my $alex = $_->get_lex_anode;
                ( defined $alex ) &&
            # candidates will be just nouns and pronouns
                ( $alex->tag =~ /^[N|P]/ ) &&
            # we omit 1st and 2nd person pronouns as candidates
                ( $alex->tag !~ /^P/ || !defined $banned_prons{$alex->lemma} )
            }
        } @sent_preceding;

    # reverse to ensure the closer candidates to be indexed with lower numbers
    my @reversed_cands = reverse @cands;
    return \@reversed_cands;
}



sub _find_positive_cands {
    my ($self, $jnode, $cands) = @_;
    my $non_gram_ante;

    my %cands_hash = map {$_->id => $_} @$cands;
    my @antes = $jnode->get_coref_text_nodes;

    if (@antes > 0) {
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
    
    while  (@gram_antes > 0) {
        $ante = $gram_antes[0];
        @gram_antes = $ante->get_coref_gram_nodes;
    }
    
    if (!defined $cands_hash->{$ante->id}) {
        return undef;
    }
    return $ante;
}

# TODO doc

1;

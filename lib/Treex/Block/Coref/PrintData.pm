package Treex::Block::Coref::PrintData;
use Moose;
use Treex::Core::Common;
use List::Util;

use Treex::Tool::Align::Utils;
use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Coref::SupervisedBase';

has 'labeled' => ( is => 'ro', isa => 'Bool', default => 1);

sub BUILD {
    my ($self) = @_;
    $self->_feature_extractor;
    $self->_ante_cands_selector;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    # TODO should this be possibly moved to a separate block ???
    # copy labels from the gold data first
    if ($self->labeled) {
        foreach my $bundle ($doc->get_bundles) {
            my $ttree = $bundle->get_tree($self->language, 't', $self->selector);
            foreach my $tnode ($ttree->get_descendants) {
                next if (!Treex::Tool::Coreference::NodeFilter::matches($tnode, $self->node_types));
                $self->_copy_coref_from_alignment($tnode);
            }
        }
    }
   
    # initialize global features
    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_filtered_tnode {
    my ( $self, $tnode ) = @_;

    return if ( $tnode->is_root );
    
    my $acs = $self->_ante_cands_selector;
    my $fe = $self->_feature_extractor;

    my @cands = $acs->get_candidates($tnode);
    my $losses = $self->labeled ? is_text_coref($tnode, @cands) : undef;

    if (!$self->labeled || $losses) {
        my ($feats, $comments) = $self->get_features_comments($tnode, \@cands);
        my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);

        print {$self->_file_handle} $instance_str;
    }
}

sub _treat_generated_node_over_parent {
    my ($self, $tnode, $align_filter) = @_;
    
    return 0 if (!$tnode->is_generated);
    my $par = $tnode->get_parent;
    return 0 if (!$par);
    my ($ref_par) = Treex::Tool::Align::Utils::aligned_transitively([$par], [$align_filter]);
    return 0 if (!$ref_par);
    my ($ref_eq) = grep {$_->functor eq $tnode->functor} $ref_par->get_echildren;
    return 0 if (!$ref_eq);
    my ($src_ante) = Treex::Tool::Align::Utils::aligned_transitively([$ref_eq], [$align_filter]);
    return 0 if (!$src_ante);
    return 0 if ($src_ante == $tnode);
    # connect only the nodes with the same functor
    return 0 if ($src_ante->functor ne $tnode->functor);

    log_info "Adding non-existing coreference link: ". $tnode->get_address ." -> ". $src_ante->get_address;
    $tnode->add_coref_text_nodes($src_ante);

}

sub _copy_coref_from_alignment {
    my ($self, $tnode) = @_;

    $self->_clear_coref($tnode);

    my $align_filter = {rel_types => ['monolingual']};

    my ($ref_anaph) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$align_filter]);
    # no gold t-node counterpart of the anaphor
    if (!defined $ref_anaph) {
        # it might be present as a result of overgeneration within coordination constructions
        return if ($self->_treat_generated_node_over_parent($tnode, $align_filter));

        log_debug "no gold t-node counterpart of the anaphor: " . $tnode->id, 1;
        return;
    }
    my $is_gram = 1;
    my @ref_antes = $ref_anaph->get_coref_gram_nodes;
    if (!@ref_antes) {
        $is_gram = 0;
        @ref_antes = $ref_anaph->get_coref_text_nodes;
    }
    # no gold antecedents
    if (!@ref_antes) {
        log_debug "no gold antecedents" . $tnode->id, 1;
        return;
    }
    #if ($ref_ante->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/) {
    #    @ref_antes = $ref_ante->get_coap_members;
    #}
    my @src_antes = Treex::Tool::Align::Utils::aligned_transitively(\@ref_antes, [$align_filter]);

    if (!@src_antes) {
        # try finding a counterpart for any antecedent in the whole coreference chain
        my $ref_ante = $ref_antes[0];
        foreach my $ref_prev_ante ( $ref_ante->get_coref_chain ) {
            @src_antes = Treex::Tool::Align::Utils::aligned_transitively([$ref_prev_ante], [$align_filter]);
            last if ( @src_antes );
        }
    }
    # remove a possible anaphor itself
    @src_antes = grep {$_ != $tnode} @src_antes;
    # no aligned src antecedents
    if (!@src_antes) {
        log_debug "no aligned src antecedents" . $tnode->id, 1;
        return;
    }

    if ($is_gram) {
        $tnode->add_coref_gram_nodes(@src_antes);
    }
    else {
        $tnode->add_coref_text_nodes(@src_antes);
    }
}

sub _clear_coref {
    my ($self, $tnode) = @_;
    $tnode->set_attr( 'coref_gram.rf', undef );
    $tnode->set_attr( 'coref_text.rf', undef );
}

sub is_text_coref {
    my ($anaph, @cands) = @_;
    
    my @antecs = $anaph->get_coref_chain;
    #push @antecs, map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ? $_->children : () } @antecs;

    # if no antecedent, insert itself and if anaphor as candidate is on, it will be marked positive
    if (!@antecs) {
        push @antecs, $anaph;
    }

    my %antes_hash = map {$_->id => $_} @antecs;

    my @losses = map {defined $antes_hash{$_->id} ? 0 : 1} @cands;
    if (none {$_ == 0} @losses) {
        log_info "[Coref::PrintData]\tan antecedent exists but there is none among the candidates: " . $anaph->get_address;
        return;
    }
    return \@losses;
}


1;
#TODO add documentation

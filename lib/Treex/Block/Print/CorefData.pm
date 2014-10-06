package Treex::Block::Print::CorefData;

use Moose;
use Treex::Core::Common;
use Treex::Tool::ML::TabSpace::Util;
use List::Util;

extends 'Treex::Block::Write::BaseTextWriter';

has 'anaphor_as_candidate' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Bool',
    default     => 1,
    documentation => 'joint anaphoricity determination and antecedent selection',
);

has 'labeled' => ( is => 'ro', isa => 'Bool', default => 1);

has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
# TODO this should be a role, not a concrete class
    lazy        => 1,
    isa         => 'Treex::Tool::Coreference::CorefFeatures',
    builder     => '_build_feature_extractor',
);

has '_ante_cands_selector' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnteCandsGetter',
    lazy        => 1,
    builder     => '_build_ante_cands_selector',
);

has '_anaph_cands_filter' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::NodeFilter',
    builder     => '_build_anaph_cands_filter',
);

sub BUILD {
    my ($self) = @_;
    $self->_ante_cands_selector;
}

sub _build_feature_extractor {
    my ($self) = @_;
    return log_fatal "method _build_feature_extractor must be overriden in " . ref($self);
}
sub _build_ante_cands_selector {
    my ($self) = @_;
    return log_fatal "method _build_ante_cands_selector must be overriden in " . ref($self);
}
sub _build_anaph_cands_filter {
    my ($self) = @_;
    return log_fatal "method _build_anaph_cands_filter must be overriden in " . ref($self);
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    # copy labels from the gold data first
    if ($self->labeled) {
        foreach my $bundle ($doc->get_bundles) {
            my $ttree = $bundle->get_tree($self->language, 't', $self->selector);
            foreach my $tnode ($ttree->get_descendants) {
                next if (!$self->_anaph_cands_filter->is_candidate( $tnode ));
                $self->_copy_coref_from_alignment($tnode);
            }
        }
    }
   
    # initialize global features
    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_tnode {
    my ( $self, $tnode ) = @_;

    return if ( $tnode->is_root );
    return if (!$self->_anaph_cands_filter->is_candidate( $tnode ));
    
    my $acs = $self->_ante_cands_selector;
    my $fe = $self->_feature_extractor;

    my @cands = $acs->get_candidates($tnode);
    my @losses = $self->labeled ? is_text_coref($tnode, @cands) : ();

    if (!$self->labeled || @losses) {
        my $feats = $self->_feature_extractor->create_instances($tnode, \@cands);
        my $instance_str = Treex::Tool::ML::TabSpace::Util::format_multiline($feats, \@losses);

        print {$self->_file_handle} $instance_str;
    }
}

sub _copy_coref_from_alignment {
    my ($self, $tnode) = @_;

    $self->_clear_coref($tnode);

    my $align_filter = {rel_types => ['monolingual']};

    my ($ref_anaph) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$align_filter]);
    # no gold t-node counterpart of the anaphor
    if (!defined $ref_anaph) {
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
    my @src_antes = Treex::Tool::Align::Utils::aligned_transitively(\@ref_antes, [$align_filter]);

    if (!@src_antes) {
        my $ref_ante = $ref_antes[0];
        
        # try finding a coap member counterpart
        if ($ref_ante->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/) {
            ($ref_ante) = $ref_ante->get_children;
            @src_antes = Treex::Tool::Align::Utils::aligned_transitively([$ref_ante], [$align_filter]);
        }
        # try finding a counterpart for any antecedent in the whole coreference chain
        else {
            foreach my $ref_prev_ante ( $ref_ante->get_coref_chain ) {
                @src_antes = Treex::Tool::Align::Utils::aligned_transitively([$ref_prev_ante], [$align_filter]);
                last if ( @src_antes );
            }
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
    push @antecs, map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ? $_->children : () } @antecs;

    # if no antecedent, insert itself and if anaphor as candidate is on, it will be marked positive
    if (!@antecs) {
        push @antecs, $anaph;
    }

    my %antes_hash = map {$_->id => $_} @antecs;

    my @losses = map {defined $antes_hash{$_->id} ? 0 : 1} @cands;
    return () if all {$_ == 1} @losses;
    return @losses;
}


1;

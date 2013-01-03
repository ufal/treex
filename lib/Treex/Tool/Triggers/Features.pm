package Treex::Tool::Triggers::Features;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Context::Sentences;
use Treex::Tool::Coreference::ContentWordFilter;
use Treex::Tool::IR::ESA;
use Treex::Tool::Clustering::GoogleNGrams;
use Treex::Tool::Triggers::FeatureFilter;

# TODO it should be coordinated by a config fil
has 'prev_sents_num' => ( isa => 'Num', is => 'ro', default => 2, required => 1 );
has 'next_sents_num' => ( isa => 'Num', is => 'ro', default => 0, required => 1 );
has 'preceding_only' => ( isa => 'Bool', is => 'ro', default => 0, required => 1 );
has 'following_only' => ( isa => 'Bool', is => 'ro', default => 0, required => 1 );
has 'add_self'       => ( isa => 'Bool', is => 'ro', default => 0, required => 1 );

has 'filter_config' => (
    isa => 'Str',
    is => 'ro',
);

has '_filter' => (
    isa => 'Treex::Tool::Triggers::FeatureFilter',
    is => 'ro',
    lazy => 1,
    builder => '_build_filter',
);

has 'phrase_clusters_storable_path' => (
    is => 'ro',
    isa => 'Str',
    default => '/net/cluster/TMP/mnovak/phrase_clusters/data/singleWordClusters.storable.gz',
    required => 1,
);

has '_context_nodes_getter' => (
    isa => 'Treex::Tool::Context::Sentences',
    is => 'ro',
    required => 1,
    builder => '_build_context_nodes_getter',
);

has '_content_word_filter' => (
    isa => 'Treex::Tool::Coreference::ContentWordFilter',
    is => 'ro',
    builder => '_build_content_word_filter',
);

has '_esa_provider' => (
    isa => 'Treex::Tool::IR::ESA',
    is => 'ro',
    lazy => 1,
    builder => '_build_esa',
);

has '_phrase_clustering' => (
    isa => 'Treex::Tool::Clustering::GoogleNGrams',
    is => 'ro',
    lazy => 1,
    builder => '_build_clusters',
);

sub BUILD {
    my ($self) = @_;
    #$self->_phrase_clustering;

    if (defined $self->filter_config) {
        $self->_filter;
    }
}

sub _build_filter {
    my ($self) = @_;
    my $filter = Treex::Tool::Triggers::FeatureFilter->new({
        config_file_path => $self->filter_config
    });
    return $filter;
}

sub _build_content_word_filter {
    my ($self) = @_;
    return Treex::Tool::Coreference::ContentWordFilter->new();
}

sub _build_context_nodes_getter {
    my ($self) = @_;

    my $cng = Treex::Tool::Context::Sentences->new({nodes_within_czeng_blocks => 1});
    return $cng;
}

sub _build_esa {
    my ($self) = @_;
    return Treex::Tool::IR::ESA->new();
}

sub _build_clusters {
    my ($self) = @_;
    my $clusters = Treex::Tool::Clustering::GoogleNGrams->new();
    $clusters->load($self->phrase_clusters_storable_path);
    return $clusters;
}

sub _weighted_feats {
    my ($self, $feat_weight, $weighted) = @_;
    my @feats = ();
    if ($weighted) {
        @feats = map {$_ . "::" . $feat_weight->{$_}} keys %$feat_weight;
    }
    else {
        @feats = keys %$feat_weight;
    }
    return \@feats;
}

sub create_instance {
    my ($self, $tnode, $types, $weights) = @_;
    my %types_hash = map {$_ => 1} @$types;

    my @instance = ();
    if ($types_hash{bow}) {
        push @instance, @{$self->create_lemma_instance($tnode, $weights)};
    }
    if ($types_hash{esa}) {
        push @instance, @{$self->create_esa_instance($tnode, $weights)};
    }
    if ($types_hash{cluster}) {
        push @instance, @{$self->create_phrase_cluster_instance($tnode, $weights)};
    }
    if (defined $self->filter_config) {
        @instance = grep {defined $_} (map {$self->_filter->filter_feature($_)} @instance);
    }
    return \@instance;
}

sub create_lemma_instance {
    my ($self, $tnode, $weights) = @_;
        
    my $trigger_nodes = $self->_get_context_nodes( $tnode );
    my $feat_weight = $self->_extract_lemmas($tnode, $trigger_nodes);
    return $self->_weighted_feats($feat_weight, $weights);
}

sub create_esa_instance {
    my ($self, $tnode, $n) = @_;
        
    my $trigger_nodes = $self->_get_context_nodes( $tnode );
    if (@$trigger_nodes == 0) {
        return {};
    }
    return $self->_extract_esa_vector($trigger_nodes, $n)
}

sub _get_context_nodes {
    my ($self, $node) = @_;

    my @nodes = $self->_context_nodes_getter->nodes_in_surroundings(
        $node, -$self->prev_sents_num, $self->next_sents_num, { 
            preceding_only => $self->preceding_only,
            following_only => $self->following_only,
            add_self => $self->add_self,
        }
    );
    @nodes = grep {$self->_content_word_filter->is_candidate($_)} @nodes;
    return \@nodes;
}

sub create_phrase_cluster_instance {
    my ($self, $tnode, $weights) = @_;

    my %feats = ();
    
    my %tnode_feats = $self->_extract_cluster_feats($tnode, 'node');
    @feats{keys %tnode_feats} = values %tnode_feats;
    
    #my ($parent) = $tnode->get_eparents( { or_topological => 1 } );
    #if (!$parent->is_root) {
    #    my %par_feats = $self->_extract_cluster_feats($parent, 'parent');
    #    @feats{keys %par_feats} = values %par_feats;
    #}

    return $self->_weighted_feats(\%feats, $weights);;
}

sub _extract_cluster_feats {
    my ($self, $tnode, $prefix) = @_;
    
    my %feats = ();
    if (!defined $tnode->t_lemma) {
        print STDERR "UNDEF_ADDR: " . $tnode->get_address() . "\n";
    }
    my $clusters = $self->_phrase_clustering->clusters_for_phrase($tnode->t_lemma);
    
    my @sorted_clus = sort {$clusters->{$b} <=> $clusters->{$a}} keys %$clusters;
    foreach my $i (1 .. scalar @sorted_clus) {
        #my $feat_str = sprintf "cluster-%s-%02d=%s", $prefix, $i, $sorted_clus[$i-1];
        my $feat_str = sprintf "cluster-%s=%s", $prefix, $sorted_clus[$i-1];
        $feats{$feat_str} = $clusters->{$sorted_clus[$i-1]};
    }
    return %feats;
}

sub _extract_esa_vector {
    my ($self, $nodes, $n) = @_;
    my $text = join " ", map {$_->t_lemma} @$nodes;
    my %vector = $self->_esa_provider->esa_vector_n_best($text, $n);
    my %feats = map {"esa_" . $_ => $vector{$_}} keys %vector;
    return \%feats;
}

sub _extract_lemmas {
    my ($self, $tnode, $nodes) = @_;

    my $tnode_sentpos = $tnode->get_bundle->get_position();
    my $tnode_wordpos = $tnode->wild->{doc_ord};

    my %lemmas = map {
        my $sent_dist = $_->get_bundle->get_position() - $tnode_sentpos;
        my $word_dist;

        # TODO why is wild->{doc_ord} undefined?
        {
            no warnings 'uninitialized';
            $word_dist = $_->wild->{doc_ord} - $tnode_wordpos;
        }

        my $lemma = $_->t_lemma;
        $lemma =~ s/ /_/g;
        $lemma =~ s/\t/__/g;
        $lemma =~ s/##/__/g;
        my $key = sprintf "bow_s%d_w%d=%s", $sent_dist, $word_dist, lc($lemma); 
        $key => 1
    } @$nodes;
    
    return \%lemmas;
    #return sort keys %lemmas;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Triggers::Features

=head1 DESCRIPTION

Features for trigger based models. Features are t-lemmas of the content words
from the previous context given by the parameter C<prev_sents_num>. 

=head1 PARAMETERS

=over

=item prev_sents_num

The size of the previous context (in sentences) from which the features
are extracted.

=back

=head1 METHODS

=over

=item create_instance

Returns a hash reference whose keys are features and values are
values of the features.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

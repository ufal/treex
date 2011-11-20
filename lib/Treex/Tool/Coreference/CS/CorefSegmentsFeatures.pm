package Treex::Tool::Coreference::CS::CorefSegmentsFeatures;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::CS::PronAnaphFilter;
use Treex::Tool::Coreference::SynonTranslDictModel;

with 'Treex::Tool::Coreference::CorefSegmentsFeatures';

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    builder     => '_build_feature_names',
);

has 'sent_range' => (
    is  => 'rw',
    isa => 'Int',
    default => 3,
    required => 1,
);

has '_synon_model' => (
    is  => 'ro',
    isa => 'Treex::Tool::Coreference::SynonTranslDictModel',
    required => 1,
    builder => '_build_synon_model',
);

has '_perspron_filter' => (
    is          => 'ro',
    isa         => 'Treex::Tool::Coreference::AnaphFilter',
    required    => 1,
    builder     => '_build_perspron_filter',
);
has '_demonpron_filter' => (
    is  => 'ro',
    isa => 'CodeRef',
    builder => '_build_demonpron_filter',
    required => 1,
);
has '_noun_ctx_equal' => (
    is      => 'rw',
    isa     => 'HashRef[Num]',
);
has '_noun_ctx_synon' => (
    is      => 'rw',
    isa     => 'HashRef[Num]',
);

sub _build_feature_names {
    my ($self) = @_;

    my @feat_names = qw(
        r_perspron_first_clause
        r_demonpron_first_clause
        r_equal_nouns
    );
    return \@feat_names;
        #r_synon_nouns
}

sub _build_synon_model {
    my ($self) = @_;
    return Treex::Tool::Coreference::SynonTranslDictModel->new();
}

sub _build_perspron_filter {
    my ($self) = @_;
    return Treex::Tool::Coreference::CS::PronAnaphFilter->new();
}

sub _build_demonpron_filter {
    my ($self) = @_;

    my $filter = sub {
        my $node = shift @_; 
        my $anode = $node->get_lex_anode;
        
        return 0 if (!defined $anode);
        
        my $subpos = substr($anode->tag, 1, 1);
        return ($subpos eq 'D');
    };
    return $filter;
}

sub _in_first_clause_count {
    my ($self, $tree, $lang, $filter) = @_;

    # TODO zone should be parametrized
    #foreach my $tree (map { $_->get_tree($lang, 't', $self->selector) } $doc->get_bundles) {
    
    my @nodes = sort { $a->clause_number <=> $b->clause_number } $tree->get_descendants;
    my @first_clause_nodes = grep { $_->clause_number == 1 } @nodes;
    
    my @result_nodes = grep { &$filter($_) } @first_clause_nodes;
    
    #return (@result_nodes > 0) || 0;
    return (scalar @result_nodes);
}

sub perspron_in_first_clause {
    my ($self, $tree) = @_;

    my $filter = sub { $self->_perspron_filter->is_candidate(shift @_) };
    return $self->_in_first_clause_count($tree, 'cs', $filter);
}

sub demonpron_in_first_clause {
    my ($self, $tree) = @_;
    
    my $filter = $self->_demonpron_filter;
    return $self->_in_first_clause_count($tree, 'cs', $filter);
}

sub _sigmoid {
    my ($self, $x) = @_;

    return (2 / (1 + exp(-$x))) - 1; 
}

sub equal_nouns {
    my ($self, $trees) = @_;

    my $sim_f = sub { $_[0] eq $_[1] };
    my $feat_vals = $self->similar_nouns($trees, $sim_f);
    $self->_set_noun_ctx_equal( $feat_vals );
}

sub synon_nouns {
    my ($self, $trees) = @_;

    my $sim_f = sub { $self->_synon_model->are_synonymous($_[0], $_[1]) };
    my $feat_vals = $self->similar_nouns($trees, $sim_f);
    $self->_set_noun_ctx_synon( $feat_vals );
}

sub similar_nouns {
    my ($self, $trees, $are_similar_f) = @_;

    my $sent_range = $self->sent_range;
    my @final_freqs_rev = ();
    my @queue = ();

    my $prev_blockid = undef;

    foreach my $tree (reverse @$trees) {

        my $curr_blockid = $tree->get_bundle->attr('czeng/blockid');
        if (defined $prev_blockid && ($prev_blockid ne $curr_blockid)) {
            push @final_freqs_rev, @queue;
            @queue = ();
        }
        $prev_blockid = $curr_blockid;

        # do not collect frequencies for sentences further than $sent_range
        if (@queue > $sent_range) {
            push @final_freqs_rev, (shift @queue);
        }

        # prepare a bag-of-nouns of the current sentence
        my @curr_nouns = grep {
            my $anode = $_->get_lex_anode; 
            (defined $anode) && ($anode->tag =~ /^NN.*/)} $tree->get_descendants;
        my %curr_lemma_freqs;
        $curr_lemma_freqs{$_->t_lemma}++ for @curr_nouns;

        # update frequencies in the previous sentences
        foreach my $lemma_freqs (@queue) {
            foreach my $lemma1 (keys %$lemma_freqs) {
                foreach my $lemma2 (keys %curr_lemma_freqs) {
                    #$lemma_freqs->{$lemma1} += 
                    #    $curr_lemma_freqs{$lemma2} * &$are_similar_f($lemma1, $lemma2);
                    $lemma_freqs->{$lemma1} ||= (&$are_similar_f($lemma1, $lemma2) ? 1 : 0);
                }
            }
        }

        my %curr_lemmas_empty = map {$_ => 0} keys %curr_lemma_freqs;
        push @queue, \%curr_lemmas_empty;
    }
    # insert the remaining frequencies
    push @final_freqs_rev,  @queue;
    
    my $feat_vals = {};

    my $i = 0;
    foreach my $freq (reverse @final_freqs_rev) {

        my $total_freq = 0;
        foreach my $word (keys %$freq) {
            $total_freq += $freq->{$word};
        }

        #$feat_vals->{$trees->[$i]->id} = $self->_sigmoid($total_freq);
        $feat_vals->{$trees->[$i]->id} = $total_freq;
        $i++;
    }

    return $feat_vals;
}

sub extract_features {
    my ($self, $tree) = @_;

    my $features = {};

    $features->{'r_perspron_first_clause'} = $self->perspron_in_first_clause($tree);
    $features->{'r_demonpron_first_clause'} = $self->demonpron_in_first_clause($tree);
    $features->{'r_equal_nouns'} = $self->_noun_ctx_equal->{$tree->id};
    #$features->{'r_synon_nouns'} = $self->_noun_ctx_synon->{$tree->id};

    return $features;
}

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    if ( !$doc->get_bundles() ) {
        return;
    }
    my @trees = map { $_->get_tree( $lang, 't', $sel ) }
        $doc->get_bundles;

    $self->equal_nouns( \@trees );
    $self->synon_nouns( \@trees );
}


1;

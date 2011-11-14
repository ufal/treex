package Treex::Tool::Coreference::CS::CorefSegmentsFeatures;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::CS::PronAnaphFilter;

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
has '_noun_ctx_similarity' => (
    is      => 'rw',
    isa     => 'HashRef[Num]',
);

sub _build_feature_names {
    my ($self) = @_;

    my @feat_names = qw(
        b_perspron_first_clause
        b_demonpron_first_clause
        r_same_nouns
    );
    return \@feat_names;
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

sub _is_in_first_clause {
    my ($self, $tree, $lang, $filter) = @_;

    # TODO zone should be parametrized
    #foreach my $tree (map { $_->get_tree($lang, 't', $self->selector) } $doc->get_bundles) {
    
    my @nodes = sort { $a->clause_number <=> $b->clause_number } $tree->get_descendants;
    my @first_clause_nodes = grep { $_->clause_number == 1 } @nodes;
    
    my @result_nodes = grep { &$filter($_) } @first_clause_nodes;
    
    return (@result_nodes > 0) || 0;
}

sub perspron_in_first_clause {
    my ($self, $tree) = @_;

    my $filter = sub { $self->_perspron_filter->is_candidate(shift @_) };
    return $self->_is_in_first_clause($tree, 'cs', $filter);
}

sub demonpron_in_first_clause {
    my ($self, $tree) = @_;
    
    my $filter = $self->_demonpron_filter;
    return $self->_is_in_first_clause($tree, 'cs', $filter);
}

sub _sigmoid {
    my ($self, $x) = @_;

    return (2 / (1 + exp(-$x))) - 1; 
}

sub same_nouns {
    my ($self, $trees, $lang, $sent_range) = @_;

    my @final_freqs_rev = ();
    my @queue = ();
    
    foreach my $tree (reverse @$trees) {

        # do not collect frequencies for sentences further than $sent_range
        if (@queue > $sent_range) {
            push @final_freqs_rev, (shift @queue);
        }

        # prepare a bag-of-nouns of the current sentence
        my @curr_nouns = grep {my $anode = $_->get_lex_anode; (defined $anode) && ($anode->tag =~ /^NN.*/)} $tree->get_descendants;
        my %curr_lemma_freqs;
        $curr_lemma_freqs{$_->t_lemma}++ for @curr_nouns;

        # update frequencies in the previous sentences
        foreach my $lemma_freqs (@queue) {
            foreach my $lemma (keys %$lemma_freqs) {
                $lemma_freqs->{$lemma} += $curr_lemma_freqs{$lemma} || 0;
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

        $feat_vals->{$trees->[$i]->id} = $self->_sigmoid($total_freq);
        $i++;
    }

    $self->_set_noun_ctx_similarity( $feat_vals );
}

sub extract_features {
    my ($self, $tree) = @_;

    my $features = {};

    $features->{'b_perspron_first_clause'} = $self->perspron_in_first_clause($tree);
    $features->{'b_demonpron_first_clause'} = $self->demonpron_in_first_clause($tree);
    $features->{'r_same_nouns'} = $self->_noun_ctx_similarity->{$tree->id};

    return $features;
}

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    if ( !$doc->get_bundles() ) {
        return;
    }
    my @trees = map { $_->get_tree( $lang, 't', $sel ) }
        $doc->get_bundles;

    $self->same_nouns( \@trees, $lang, $self->sent_range );
}


1;

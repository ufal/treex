package Treex::Tool::Align::Features;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;
use Graph;
use Treex::Tool::Lexicon::UniversalTagset;
use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Lexicon::CS;
use List::MoreUtils qw/uniq/;

with 'Treex::Tool::Align::FeaturesRole';

has '_sent_graphs' => ( is => 'rw', isa => 'HashRef', default => sub {{}});
has '_subtree_aligns' => ( is => 'rw', isa => 'HashRef', default => sub {{}});
has '_curr_filename' => (is => 'rw', isa => 'Str', default => "");

my $GIZA_ORIG_RULES_FILTER = [ '!gold', '!robust', '!supervised', '.*' ];

sub _reset_global_structs {
    my ($self, $tnode) = @_;
    
    my $filename = $tnode->get_document->full_filename;
    if ($filename ne $self->_curr_filename) {
        $self->_set_curr_filename($filename);
        $self->_set_sent_graphs({});
        $self->_set_subtree_aligns({});
    }
}

sub _unary_features {
    my ($self, $node, $type) = @_;

    $self->_reset_global_structs($node);

    my $feats = {};

    if ($type eq "n1") {
        my $anaph_types = join " ", grep {$_ ne "all_anaph"} (split /,/, $node->wild->{filter_types});
        $feats->{"type^nodetype"} = $anaph_types;
    }

    #$feats->{id} = $node->get_address;
    $feats->{t_lemma} = $node->t_lemma;
    $feats->{functor} = $node->functor;
    $feats->{gen} = $node->gram_gender // "undef";
    $feats->{num} = $node->gram_number // "undef";
    $feats->{gennum} = $feats->{gen} . "_" . $feats->{num};

    my $anode = $node->get_lex_anode;
    $feats->{tag} = defined $anode ? substr($anode->tag, 0, 4) : "undef";
    $feats->{utag} = defined $anode ? Treex::Tool::Lexicon::UniversalTagset::convert_tag($anode->tag, $node->language) : "undef";
    $feats->{lemma} = defined $anode ? ( $anode->language eq "cs" ? Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma) : $anode->lemma )
                                     : "undef";
    $feats->{gennumlemma} = $feats->{gennum} . "_" . $feats->{lemma};

    my ($par) = $node->get_eparents({or_topological => 1});
    my $par_anode = $par->get_lex_anode;
    $feats->{par_utag} = defined $par_anode ? Treex::Tool::Lexicon::UniversalTagset::convert_tag($par_anode->tag, $node->language) : "undef";

    $feats->{reflex} = Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {reflexive => 1}) ? 1 : 0;

    return $feats;
}

sub _binary_features {
    my ($self, $set_features, $node1, $node2) = @_;

    my $feats = { %$set_features };

    $self->_add_align_features($feats, $node1, $node2);
    $self->_add_gram_features($feats, $node1, $node2);
    $self->_add_comb_features($feats, $node1, $node2);

    # the unary feats must be removed
    delete @$feats{keys %$set_features};

    return $feats;
}

sub _add_align_features {
    my ($self, $feats, $node1, $node2) = @_;

    # all alignmnets excpt for the gold one projected from "ref"
    # TODO: do not project gold annotation to "src" => clearer solution
    my $nodes_aligned = $node1->is_undirected_aligned_to($node2, { rel_types => $GIZA_ORIG_RULES_FILTER });
    $feats->{giza_aligned} = $nodes_aligned ? 1 : 0;


    my ($par1) = $node1->get_eparents({or_topological => 1});
    my ($par2) = $node2->get_eparents({or_topological => 1});
    my $par_aligned = $par1->is_undirected_aligned_to($par2, { rel_types => $GIZA_ORIG_RULES_FILTER });
    $feats->{par_aligned} = $par_aligned ? 1 : 0;

    $feats->{subtree_aligned_all} = $self->subtree_alignment($node1, $node2, 'all') ? 1 : 0;
    $feats->{subtree_aligned_head} = $self->subtree_alignment($node1, $node2, 'clause_head') ? 1 : 0;

    $self->_add_graph_features($feats, $node1, $node2);
}

sub _add_gram_features {
    my ($self, $feats, $node1, $node2) = @_;
    
    $feats->{t_lemma_cat} = $self->cat($feats, "t_lemma");
    $feats->{tag_cat} = $self->cat($feats, "tag");
    $feats->{utag_cat} = $self->cat($feats, "utag");
    $feats->{lemma_cat} = $self->cat($feats, "lemma");
    $feats->{functor_cat} = $self->cat($feats, "functor");
    $feats->{functor_eq}  = $self->eq($feats, "functor");

    $feats->{gen_cat} = $self->cat($feats, "gen");
    $feats->{gen_eq} = $self->eq($feats, "gen");
    $feats->{num_cat} = $self->cat($feats, "num");
    $feats->{num_eq} = $self->eq($feats, "num");
    $feats->{gennum_cat} = $self->cat($feats, "gennum");
    $feats->{gennum_eq} = $self->eq($feats, "gennum");
    $feats->{gennumlemma_cat} = $self->cat($feats, "gennumlemma");
}

sub _add_comb_features {
    my ($self, $feats, $node1, $node2) = @_;

    $feats->{alipar_functor_cat} = $feats->{functor_cat} . "_" . $feats->{par_aligned};
    $feats->{alipar_functor_eq} = $feats->{functor_eq} . "_" . $feats->{par_aligned};
    
    $feats->{alidir_n1_t_lemma} = $feats->{$self->node1_label . "_t_lemma"} . "_" . $feats->{giza_aligned};
    $feats->{alipar_n1_t_lemma} = $feats->{$self->node1_label . "_t_lemma"} . "_" . $feats->{par_aligned};
    $feats->{alisubtreeall_n1_t_lemma} = $feats->{$self->node1_label . "_t_lemma"} . "_" . $feats->{subtree_aligned_all};
    $feats->{alisubtreehead_n1_t_lemma} = $feats->{$self->node1_label . "_t_lemma"} . "_" . $feats->{subtree_aligned_head};
    
    $feats->{alidir_n2_t_lemma} = $feats->{$self->node2_label . "_t_lemma"} . "_" . $feats->{giza_aligned};
    $feats->{alipar_n2_t_lemma} = $feats->{$self->node2_label . "_t_lemma"} . "_" . $feats->{par_aligned};
    $feats->{alisubtreeall_n2_t_lemma} = $feats->{$self->node2_label . "_t_lemma"} . "_" . $feats->{subtree_aligned_all};
    $feats->{alisubtreehead_n2_t_lemma} = $feats->{$self->node2_label . "_t_lemma"} . "_" . $feats->{subtree_aligned_head};
}

sub _add_graph_features {
    my ($self, $feats, $node1, $node2) = @_;
    
    my $g = $self->_get_sent_graph($node1, $node2);
    
    my @node_path = $g->SP_Dijkstra($node1->id, $node2->id);

    $feats->{path_len} = @node_path - 1;
    $feats->{path_types} = _extract_path_types($g, @node_path);
}

sub _extract_path_types {
    my ($g, @nodes) = @_;
    my @type_seq = map {$g->get_edge_attribute($nodes[$_], $nodes[$_+1], "type")} 0 .. $#nodes-1;
    return join ",", @type_seq;
}

sub _get_sent_graph {
    my ($self, $l1_node, $l2_node) = @_;

    my $l1_ttree = $l1_node->get_root;
    my $l2_ttree = $l2_node->get_root;
    
    #log_warn "L1_ttree: " . $l1_ttree->id;
    #log_warn "L2_ttree: " . $l2_ttree->id;

    my $g = $self->_sent_graphs->{$l1_ttree->id};
    return $g if (defined $g);

    my @nodes = ($l1_ttree->get_descendants(), $l2_ttree->get_descendants());

    $g = Graph->new();
    foreach my $node (@nodes) {
        $g->set_edge_attribute($node->id, $node->get_parent->id, "type", "parent");
        $g->set_edge_attribute($node->get_parent->id, $node->id, "type", "child");
        my ($ali_nodes, $ali_types) = $node->get_directed_aligned_nodes({
            directed => 1,
            rel_types => $GIZA_ORIG_RULES_FILTER
        });
        foreach my $ali (@$ali_nodes) {
            $g->add_weighted_edge($node->id, $ali->id, 100);
            $g->add_weighted_edge($ali->id, $node->id, 100);
            $g->set_edge_attribute($node->id, $ali->id, "type", "align");
            $g->set_edge_attribute($ali->id, $node->id, "type", "align");
        }
    }
    #print STDERR join "\n", (map {join " ", (split /-t/, $_)} (split /,/, sprintf $g));
    $self->_sent_graphs->{$l1_ttree->id} = $g;
    $self->_sent_graphs->{$l2_ttree->id} = $g;

    return $g;
}

sub subtree_alignment {
    my ($self, $l1_node, $l2_node, $type) = @_;
    my $subtree_align = $self->_get_subtree_aligns($l1_node, $type);
    return defined $subtree_align->{$l2_node->id};
}

sub _get_subtree_aligns {
    my ($self, $tnode, $type) = @_;

    my $subtree_align = $self->_subtree_aligns->{$type}{$tnode->id};
    return $subtree_align if (defined $subtree_align);

    my $par = $tnode;
    while (defined $par->get_parent && defined $par->get_parent->formeme && $par->get_parent->formeme !~ /^v/) {
        $par = $par->get_parent;
    }

    my @ali_phrase_nodes = ();
    if ($type eq 'clause_head') {
        my ($an, $at) = $par->get_undirected_aligned_nodes({
            selector => $par->selector,
            rel_types => $GIZA_ORIG_RULES_FILTER
        });
        @ali_phrase_nodes = @$an;
    }
    else {
        @ali_phrase_nodes = map {
            my ($an, $at) = $_->get_undirected_aligned_nodes({
                selector => $_->selector,
                rel_types => $GIZA_ORIG_RULES_FILTER,
            });
            @$an
        } $par->get_descendants();
    }

    my @all_ali_desc = uniq map {$_->get_descendants({add_self => 1})} @ali_phrase_nodes;
    $subtree_align = { map {$_->id => 1} @all_ali_desc };

    $self->_subtree_aligns->{$type}{$tnode->id} = $subtree_align;
    return $subtree_align;
}

1;

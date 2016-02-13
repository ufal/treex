package Treex::Block::Align::Annot::Load;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

has 'from' => (is => 'ro', isa => 'Str', required => 1);
has '_align_records' => (is => 'ro', isa => 'HashRef', builder => '_build_align_records', lazy => 1);
has 'aligns' => ( is => 'ro', isa => 'Str', required => 1 );
has '_aligns_graph' => ( is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1 );

sub BUILD {
    my ($self) = @_;
    $self->_aligns_graph;
    $self->_align_records;
}

sub _build_aligns_graph {
    my ($self) = @_;
    my @align_pairs = split /;/, $self->aligns;
    my $aligns_graph = {};
    foreach my $align_pair (@align_pairs) {
        my ($langs, $type) = split /:/, $align_pair, 2;
        $type ||= "gold";
        my ($l1, $l2) = split /-/, $langs, 2;
        log_fatal "Cannot origin alignments to two different langauges from the same langauge." if (defined $aligns_graph->{$l1});
        $aligns_graph->{$l1} = [$l2, $type];
    }
    return $aligns_graph;
}

sub _build_align_records {
    my ($self) = @_;

    my $align_rec = {};

    open my $f, "<:utf8", $self->from;

    my $line_num = 0;
    my $doc_id;
    my $src_id;
    my $annot_info = {};
    my $align_info;
    my $coref_expr_type;

    while (my $line = <$f>) {
        $line_num++;
        chomp $line;
        # read the ID line
        if ($line_num == 1 || $line =~ /^ID:/) {
            ($doc_id, $src_id) = ($line =~ /^.*\/(.*)\.s?treex.*\.([^.]*)$/);
            next;
        }
        # skip surface sentences
        next if ($line =~ /^[A-Z]+:\t/);
        # read the annotated trees
        # linearized atree <=> tokenized sentence (LANG_A), linearized ttree (LANG_T), structured ttree (LANG_TT)
        if ($line =~ s/^([A-Z]+)_(T|A|TT):\t//) {
            my $lang = lc($1);
            my $style = lc($2);
            my @word_nodes = split / /, $line;
            if ($style eq "tt") {
                @word_nodes = grep {$_ ne "[" && $_ ne "]"} @word_nodes;
            }
            my @annot_idx = grep {$word_nodes[$_] =~ /^<.*>$/ && $word_nodes[$_] !~ /^<__A:.*__.*>$/} 0 .. $#word_nodes;
            my @anodes_ids = grep {defined $_} map {my ($a_id) = ($_ =~ /^<__A:(.*)__.*>$/); $a_id} @word_nodes;
            my $lang_rec = {
                style => $style,
                annot_idx => \@annot_idx,
                anodes_ids => \@anodes_ids,
            };
            $annot_info->{$lang} = $lang_rec;
            next;
        }
        # read the additional annotation info - old style ERR:
        if ($line =~ s/^ERR://) {
            my @parts = split /\t/, $line;
            $align_info = join "\t", grep {$_!~/^TYPE=/} @parts;
            ($coref_expr_type) = grep {$_ =~ /^TYPE=/} @parts;
            my @langs = sort keys %$annot_info;
            if (@langs != 2) {
                log_warn "It is not possible to reveal to which language pair the annotation info startin with ERR belongs.";
            }
            $annot_info->{__COMMON__}{info} = $align_info if ($align_info !~ /^\s*$/);
            $annot_info->{__COMMON__}{type} = $coref_expr_type;
            next;
        }
        # read the additional annotation info - new style INFO_LANG:
        if ($line =~ s/^INFO_([A-Z]+)://) {
            $annot_info->{lc($1)}{info} = $line if ($line !~ /^\s*$/);
            next;
        }
        # read the empty line
        if ($line =~ /^\s*$/) {
            $align_rec->{$doc_id}{$src_id} = $annot_info;
            $doc_id = undef;
            $src_id = undef;
            $annot_info = {};
            $line_num = 0;
        }
    }
    close $f;
    #print STDERR Dumper($align_rec);
    return $align_rec;
}

sub _nodes_linear {
    my ($ttree) = @_;
    return $ttree->get_descendants({ordered => 1});
}

sub _nodes_structured {
    my ($ttree) = @_;
    my @list = ();
    my @stack = $ttree->get_children({ordered => 1});
    while (@stack) {
        my $node = pop @stack;
        push @stack, reverse($node->get_children({ordered => 1}));
        push @list, $node;
    }
    return @list;
}

sub _find_nodes_by_idx {
    my ($bundle, $rec, $lang, $selector) = @_;

    my $tree = $bundle->get_tree($lang, substr($rec->{style}, 0, 1), $selector);
    my @all_nodes = $rec->{style} eq "tt" ? _nodes_structured($tree) : _nodes_linear($tree);
    my @ali_nodes = @all_nodes[@{$rec->{annot_idx}}];
    return \@ali_nodes;
}

sub _find_anodes_by_id {
    my ($doc, $rec, $tnodes) = @_;
    my @anodes = map {$doc->get_node_by_id($_)} @{$rec->{anodes_ids}};
    if (!@anodes && @$tnodes) {
        @anodes = map {$_->get_lex_anode} @$tnodes;
    }
    return \@anodes;
}

sub process_document {
    my ($self, $doc) = @_;

    print "UNDF DOC\n" if (!defined $doc);

    #print STDERR "DOC: " . $doc->file_stem . "\n";

    my $doc_align_records = $self->_align_records->{$doc->file_stem};
    foreach my $id (keys %$doc_align_records) {
        next if (!$doc->id_is_indexed($id));
        
        my $node = $doc->get_node_by_id($id);
        my $selector = $node->selector;
        my $rec = $doc_align_records->{$id};

        #$Data::Dumper::Maxdepth = 4;
        #print STDERR "ID: " . $node->id . "\n";
        #print STDERR Dumper($rec);

        _set_align_info($node, $rec);

        foreach my $src_lang (keys %{$self->_aligns_graph}) {
            my ($trg_lang, $align_type) = @{$self->_aligns_graph->{$src_lang}};
            my ($src_rec, $trg_rec) = map {$rec->{$_}} ($src_lang, $trg_lang);

            # making a link between a-nodes or t-nodes
            my $src_nodes = _find_nodes_by_idx($node->get_bundle, $src_rec, $src_lang, $selector);
            my $trg_nodes = _find_nodes_by_idx($node->get_bundle, $trg_rec, $trg_lang, $selector);
            _add_align($src_nodes, $trg_nodes, $align_type);
            
            # in the old format, alignment between a-nodes can be specified in t-nodes
            if (@{$src_rec->{anodes_ids}} || @{$trg_rec->{anodes_ids}}) {
                my $src_anodes = _find_anodes_by_id($doc, $src_rec, $src_nodes);
                my $trg_anodes = _find_anodes_by_id($doc, $trg_rec, $trg_nodes);
                _add_align($src_anodes, $trg_anodes, $align_type);
            }
        }
    }
    #exit();
}

sub _set_align_info {
    my ($node, $rec) = @_;
    my $src_lang = $node->language;
    # the old annotation style
    if (defined $rec->{__COMMON__}) {
        my ($trg_lang, @other_langs) = grep {$_ ne "__COMMON__" && $_ ne $src_lang} keys %$rec;
        if (@other_langs) {
            log_warn "The old ali_annot format used only for cs and en, however these languages found: " . (join ", ", ($src_lang, $trg_lang, @other_langs));
        }
        $node->wild->{align_info}{$trg_lang} = $rec->{__COMMON__}{info};
        $node->wild->{align_info}{$src_lang} = $rec->{__COMMON__}{type};
    }
    else {
        foreach my $trg_lang (keys %$rec) {
            $node->wild->{align_info}{$trg_lang} = $rec->{$trg_lang}{info};
            #log_info sprintf("Setting align info for '%s' in %s: %s", $trg_lang, $node->id, $node->wild->{align_info}{$trg_lang} // "__UNDEF__");
        }
    }
}

sub _add_align {
    my ($src_nodes, $trg_nodes, $type) = @_;
    
    foreach my $src_node (@$src_nodes) {
        foreach my $trg_node (@$trg_nodes) {
            my $lemma_func = $src_node->get_layer eq "a" ? "lemma" : "t_lemma";
            log_info sprintf("Adding alignment '%s' between nodes: %s -> %s (%s -> %s)", $type, $src_node->id, $trg_node->id, $src_node->$lemma_func, $trg_node->$lemma_func);
            Treex::Tool::Align::Utils::add_aligned_node($src_node, $trg_node, $type);
        }
    }
}

1;

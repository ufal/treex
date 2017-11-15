package Treex::Block::Align::Annot::Load;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;
use Data::Printer;

extends 'Treex::Core::Block';

has 'from' => (is => 'ro', isa => 'Str', required => 1);
has '_align_records' => (is => 'ro', isa => 'HashRef', builder => '_build_align_records', lazy => 1);
has 'aligns' => ( is => 'ro', isa => 'Str', required => 1 );
has '_aligns_graph' => ( is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1 );
has '_src_lang' => ( is => 'rw', isa => 'Str' );

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
    my $sent_id;
    my $src_id;
    my $annot_info = {};
    my $align_info;
    my $coref_expr_type;

    while (my $line = <$f>) {
        $line_num++;
        chomp $line;
        # read the ID line
        if ($line_num == 1 || $line =~ /^ID:/) {
            ($doc_id, $sent_id, $src_id) = ($line =~ /^.*\/(.*)\.s?treex##([0-9]+)\.([^.]*)$/);
#            printf STDERR "DOC: %s, SENT: %s, SRC: %s\n", ($doc_id, $sent_id, $src_id);
            next;
        }
        # skip surface sentences
        next if ($line =~ /^[A-Z]+:\t/);
        # read the annotated trees
        # linearized atree <=> tokenized sentence (LANG_A), linearized ttree (LANG_T), structured ttree (LANG_TT)
        if ($line =~ s/^([A-Z]+)_(T|A|TT):\t//) {
            my $lang = lc($1);
            if (!defined $self->_src_lang) {
                $self->_set_src_lang($lang);
            }
            my $style = lc($2);
            my @word_nodes = split / /, $line;
            if ($style eq "tt") {
                @word_nodes = grep {$_ ne "[" && $_ ne "]"} @word_nodes;
            }
            my @annot_idx;
            my @anodes_ids;
            for (my $i = 0; $i < @word_nodes; $i++) {
                if ($word_nodes[$i] =~ /^<__A:(.*)__(.*)>$/) {
                    push @anodes_ids, $1;
                }
                elsif ($word_nodes[$i] =~ /^<(.*)>$/) {
                    push @annot_idx, [$i, $1];
                }
            }
            my $lang_rec = {
                style => $style,
                annot_idx => \@annot_idx,
                anodes_ids => \@anodes_ids,
                sent_id => $sent_id,
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
            $sent_id = undef;
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

sub _check_lex {
    my ($nodes, $lexs) = @_;
    for (my $i = 0; $i < @$nodes; $i++) {
        my $form = $nodes->[$i]->get_layer eq "a" ? $nodes->[$i]->form : (
            defined $nodes->[$i]->get_lex_anode ? $nodes->[$i]->get_lex_anode->form : $nodes->[$i]->t_lemma );
        if ($lexs->[$i] !~ /^$form/) {
            log_warn sprintf "Form/t_lemma of the selected node %s does not match the one in the annotation file: %s <> %s",
                $nodes->[$i]->get_address, $form, $lexs->[$i];
            return 0;
        }
    }
    return 1;
}

sub _find_nodes_by_idx {
    my ($bundle, $rec, $lang, $selector) = @_;

    my $tree = $bundle->get_tree($lang, substr($rec->{style}, 0, 1), $selector);
    my @all_nodes = $rec->{style} eq "tt" ? _nodes_structured($tree) : _nodes_linear($tree);
    my @idxs = map {$_->[0]} @{$rec->{annot_idx}};
    my @lexs = map {$_->[1]} @{$rec->{annot_idx}};
#    log_info "IDXS: ". join " ", @idxs;
#    log_info "LEXS: ". join " ", @lexs;
#    log_info "ALL_NODES: " . join " ", map {$_->form} @all_nodes;
    my @ali_nodes = grep {defined $_} @all_nodes[@idxs];
    if (@ali_nodes < @lexs) {
        log_warn sprintf "The sentence %d in the document %s is shorter than the one in the align annot file.", $rec->{sent_id}, $bundle->get_document->file_stem;
        return;
    }
    return if (!_check_lex(\@ali_nodes, \@lexs));
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
    my @ali_rec_keys = keys %{$self->_align_records};
#    p $doc->file_stem;
#    p @ali_rec_keys;
#    p $doc_align_records;
    foreach my $id (keys %$doc_align_records) {
        my $rec = $doc_align_records->{$id};
        
        my $node;
        my $selector = $self->selector;
        # if a node that should carry the "align_info" structure can be found by its ID
        if ($doc->id_is_indexed($id)) {        
            $node = $doc->get_node_by_id($id);
            $selector = $node->selector;
        }
        # if it has to be inferred from the annotated sentences
        else {
            my @bundles = $doc->get_bundles;
            my $src_rec = $rec->{$self->_src_lang};
            my $src_nodes = _find_nodes_by_idx($bundles[$src_rec->{sent_id}-1], $src_rec, $self->_src_lang, $selector);
            ($node) = @$src_nodes if (defined $src_nodes);
        }
        next if (!defined $node);
        
        my $annotated_langs = _set_align_info($node, $rec);


        #$Data::Dumper::Maxdepth = 4;
        #print STDERR "ID: " . $node->id . "\n";
        #print STDERR Dumper($rec);

        my @src_langs = sort keys %{$self->_aligns_graph};
        foreach my $src_lang (sort keys %{$self->_aligns_graph}) {
            my ($trg_lang, $align_type) = @{$self->_aligns_graph->{$src_lang}};
            my ($src_rec, $trg_rec) = map {$rec->{$_}} ($src_lang, $trg_lang);

            next if (!defined $annotated_langs->{$src_lang});
            next if (!defined $annotated_langs->{$trg_lang});
        
            # making a link between a-nodes or t-nodes
            my $src_nodes = _find_nodes_by_idx($node->get_bundle, $src_rec, $src_lang, $selector);
            if (!defined $src_nodes && $node->wild->{align_info}{$src_lang} !~ /__UNMATCHED__/) {
                $node->wild->{align_info}{$src_lang} = '__UNMATCHED__ ' . $node->wild->{align_info}{$src_lang};
            }
            my $trg_nodes = _find_nodes_by_idx($node->get_bundle, $trg_rec, $trg_lang, $selector);
            if (!defined $trg_nodes && $node->wild->{align_info}{$trg_lang} !~ /__UNMATCHED__/) {
                $node->wild->{align_info}{$trg_lang} = '__UNMATCHED__ ' . $node->wild->{align_info}{$trg_lang};
            }
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
    my %annotated_langs = ();
    # the old annotation style
    if (defined $rec->{__COMMON__}) {
        my ($trg_lang, @other_langs) = grep {$_ ne "__COMMON__" && $_ ne $src_lang} keys %$rec;
        if (@other_langs) {
            log_warn "The old ali_annot format used only for cs and en, however these languages found: " . (join ", ", ($src_lang, $trg_lang, @other_langs));
        }
        if (defined $rec->{__COMMON__}{info}) {
            $annotated_langs{$src_lang} = 1;
            $annotated_langs{$trg_lang} = 1;
            $node->wild->{align_info}{$trg_lang} = $rec->{__COMMON__}{info};
            $node->wild->{align_info}{$src_lang} = $rec->{__COMMON__}{type} if (defined $rec->{__COMMON__}{type});
        }
    }
    else {
        foreach my $trg_lang (keys %$rec) {
            if (defined $rec->{$trg_lang}{info}) {
                $annotated_langs{$trg_lang} = 1;
                $node->wild->{align_info}{$trg_lang} = $rec->{$trg_lang}{info};
            }
            #log_info sprintf("Setting align info for '%s' in %s: %s", $trg_lang, $node->id, $node->wild->{align_info}{$trg_lang} // "__UNDEF__");
        }
    }
    return \%annotated_langs;
}

sub _add_align {
    my ($src_nodes, $trg_nodes, $type) = @_;
    
    foreach my $src_node (@$src_nodes) {
        foreach my $trg_node (@$trg_nodes) {
            Treex::Tool::Align::Utils::check_gold_aligns_from_to($src_node, $trg_node, ["gold", "coref_gold"]);
            Treex::Tool::Align::Utils::check_gold_aligns_from_to($trg_node, $src_node, ["gold", "coref_gold"]);

            my $lemma_func = $src_node->get_layer eq "a" ? "lemma" : "t_lemma";
            log_info sprintf("Adding alignment '%s' between nodes: %s -> %s (%s -> %s)", $type, $src_node->id, $trg_node->id, $src_node->$lemma_func, $trg_node->$lemma_func);
            Treex::Tool::Align::Utils::add_aligned_node($src_node, $trg_node, $type);
        }
    }
}

1;

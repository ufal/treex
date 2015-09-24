package Treex::Block::W2A::GazeteerMatch;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use List::MoreUtils qw/none all/;
use List::Util qw/sum/;

extends 'Treex::Core::Block';

has 'phrase_list_path' => ( is => 'ro', isa => 'Str' );
# idx removed: libreoffice_16090, libreoffice_16123, libreoffice_73656
has 'trg_lang' => (is => 'ro', isa => 'Str');

has 'filter_id_prefixes' => ( is => 'ro', isa => 'Str', default => 'all' );


has '_trie' => ( is => 'ro', isa => 'HashRef', builder => '_build_trie', lazy => 1);

my %PHRASE_LIST_PATHS = (
    'en' => {
        'cs' => 'data/models/gazeteer/cs_en/20150821_005.IT.cs_en.cs.gaz.gz',
        'es' => 'data/models/gazeteer/es_en/20150821_002.IT.es_en.es.gaz.gz',
        'eu' => 'data/models/gazeteer/eu_en/20150821_002.IT.eu_en.eu.gaz.gz',
        'nl' => 'data/models/gazeteer/nl_en/20150821_004.IT.nl_en.nl.gaz.gz',
        'pt' => 'data/models/gazeteer/pt_en/20150821_002.IT.pt_en.pt.gaz.gz',
    },
);

sub BUILD {
    my ($self) = @_;
    if (!defined $self->phrase_list_path && defined $self->trg_lang) {
        $self->{phrase_list_path} = $PHRASE_LIST_PATHS{$self->trg_lang}{$self->language};
    }
    return;
}

sub _build_trie {
    my ($self) = @_;

    log_info "Loading the phrase list...";
    log_info "Building a trie for searching...";

    my $path = require_file_from_share($self->phrase_list_path);
    open my $fh, "<:gzip:utf8", $path;

    my $trie = {};
    my $filter_id_prefixes = $self->filter_id_prefixes ne 'all' ?
        join "|", map {"(" . $_ . ")"} (split /,/, $self->filter_id_prefixes) :
        undef;

    while (my $line = <$fh>) {
        chomp $line;
        my ($id, @phrase_rest) = split /\t/, $line;

        next if (defined $filter_id_prefixes && $id !~ /^$filter_id_prefixes/);

        my $phrase = join " ", @phrase_rest;
        _insert_phrase_to_trie($trie, $phrase, $id);
    }
    close $fh;

    #log_info Dumper($trie);

    return $trie;
}

sub process_start {
    my ($self) = @_;
    $self->_trie;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my $matches = $self->_match_phrases_in_atree($atree, $self->_trie);
    
    # assess which candidates are likely to be entity phrases and return only the mutually exclusive ones
    my $entities = $self->_resolve_entities($matches);


    #$Data::Dumper::Maxdepth = 2;
    #log_info Dumper($entities);

    # transform the a-tree
    my $entity_anodes = $self->_collapse_entity_anodes($atree, $entities);
    
    my $collapsed_entities = $self->_collapse_neighboring_entities($entity_anodes);
    
    $entity_anodes = $self->_collapse_entity_anodes($atree, $collapsed_entities);

}

my $INFO_LABEL = "__INFO__";

sub _insert_phrase_to_trie {
    my ($trie, $phrase, $id) = @_;

    #my $debug = 0;
    #if ($id eq "libreoffice_25826") {
    #    $debug = 1;
    #}

    return if ($phrase =~ /^\s*$/);

    my @words = map {lc($_)} (split / +/, $phrase);
    my $next_word = shift @words;
    while (defined $next_word && defined $trie->{$next_word}) {
        #log_info "NEXT_WORD_GET: " . $next_word if ($debug);
        $trie = $trie->{$next_word};
        $next_word = shift @words;
    }

    # there is a tail of remaining words
    if (defined $next_word) {
        my $suffix_hash = {};
        while ($next_word) {
            #log_info "NEXT_WORD_SET: " . $next_word if ($debug);
            $trie->{$next_word} = {}; 
            $trie = $trie->{$next_word};
            $next_word = shift @words;
        }
        my $info = [$id, $phrase];
        $trie->{$INFO_LABEL} = $info;
    }
    # all words are indexed in a trie
    else {
        my $info = $trie->{$INFO_LABEL};
        if (!defined $info) {
            $info = [$id, $phrase];
            $trie->{$INFO_LABEL} = $info;
        }
        # else: this phrase is already stored - skip it
    }
}

sub _match_phrases_in_atree {
    my ($self, $atree, $trie) = @_;
    
    my @anodes = $atree->get_children( {ordered => 1} );

    my @matches = ();
    my @unproc_trie_nodes = ();
    my @unproc_anodes = ();

    foreach my $anode (@anodes) {
        unshift @unproc_trie_nodes, $trie;

        my $word = lc($anode->form);

        @unproc_trie_nodes = map {$_->{$word}} @unproc_trie_nodes;
        my @found = map {defined $_ ? 1 : 0} @unproc_trie_nodes;
        unshift @unproc_anodes, [];
        @unproc_anodes = grep {defined $_} 
            map { if ($found[$_]) {
                    [ @{$unproc_anodes[$_]}, $anode ] 
                  } else {
                    undef;
                  }
                } 0 .. $#unproc_anodes;
        @unproc_trie_nodes = grep {defined $_} @unproc_trie_nodes;

        my @new_matches = map {[@{$unproc_trie_nodes[$_]->{$INFO_LABEL}}, $unproc_anodes[$_]]} 
            grep {defined $unproc_trie_nodes[$_]->{$INFO_LABEL}} 0 .. $#unproc_trie_nodes;
        push @matches, @new_matches;
    }
    return \@matches;
}

sub _resolve_entities {
    my ($self, $matches) = @_;
    
    #$Data::Dumper::Maxdepth = 2;
    #log_info Dumper($matches);

    my @scores = map {$self->score_match($_)} @$matches;

    #log_info Dumper(\@scores);

    my @accepted_idx = grep {$scores[$_] > 0} 0 .. $#scores;
    
    my @sorted_idx = sort {$scores[$b] <=> $scores[$a]} @accepted_idx;

    my %covered_anode = ();
    my @resolved_entities = ();
    foreach my $idx (@sorted_idx) {
        my $cand = $matches->[$idx];
        if (none {$covered_anode{$_->id}} @{$cand->[2]}) {
            push @resolved_entities, $cand;
            $covered_anode{$_->id} = 1 foreach (@{$cand->[2]});
        }
    }
    
    log_info Dumper(\@resolved_entities);

    return \@resolved_entities;
}

sub score_match {
    my ($self, $match) = @_;

    my @anodes = @{$match->[2]};
    my @forms = map {$_->form} @anodes;

    my $full_str = join " ", @forms;
    
    my $full_str_score = ($full_str eq $match->[1]) ? 2 : 0;

    my $non_alpha_penalty = ($full_str !~ /[a-zA-Z]/) ? -100 : 0;

    my $first_starts_capital = ($forms[0] =~ /^\p{IsUpper}/) ? 10 : -10;
    my $entity_starts_capital = ($match->[1] =~ /^\p{IsUpper}/) ? 10 : -50;

    my $all_start_capital = (all {$_ =~ /^\p{IsUpper}/} @forms) ? 1 : -1;
    my $no_first = (all {$_->ord > 1} @anodes) ? 1 : -50;

    my $last_menu = ($forms[$#forms] eq "menu") ? -50 : 0;

    my @scores = ( $full_str_score, $non_alpha_penalty, $all_start_capital, 
        $no_first, $first_starts_capital, $entity_starts_capital, $last_menu );
    my $score = (sum @scores) * (scalar @anodes);
    
    return $score;
}

sub _collapse_neighboring_entities {
    my ($self, $entity_anodes) = @_;

    my %covered_anodes = ();
    my @collapsed_entities = ();

    my $delimiter_regex = $self->get_delimiter_regex();

    foreach my $anode (@$entity_anodes) {
        my $id = $anode->wild->{gazeteer_entity_id};
        my $phrase = $anode->wild->{matched_item};
        
        next if (defined $covered_anodes{$anode->id});

        $covered_anodes{$anode->id} = 1;
    
        my @consec_ids = ( $id );
        my @consec_phrases = ( $phrase );
        my @consec_anodes = ( $anode );

        my $prev_anode = $anode->get_prev_node;
        while (defined $prev_anode && (defined $prev_anode->wild->{gazeteer_entity_id} || $prev_anode->form =~ /$delimiter_regex/)) {
            if (defined $prev_anode->wild->{gazeteer_entity_id}) {
                unshift @consec_ids, $prev_anode->wild->{gazeteer_entity_id};
                unshift @consec_phrases, $prev_anode->wild->{matched_item};
            }
            else {
                unshift @consec_ids, "__PUNCT__";
                unshift @consec_phrases, $prev_anode->form;
            }
            unshift @consec_anodes, $prev_anode;
            $covered_anodes{$prev_anode->id} = 1;
            $prev_anode = $prev_anode->get_prev_node;
        }
        my $next_anode = $anode->get_next_node;
        while (defined $next_anode && (defined $next_anode->wild->{gazeteer_entity_id} || $next_anode->form =~ /$delimiter_regex/)) {
            if (defined $next_anode->wild->{gazeteer_entity_id}) {
                push @consec_ids, $next_anode->wild->{gazeteer_entity_id};
                push @consec_phrases, $next_anode->wild->{matched_item};
            }
            else {
                push @consec_ids, "__PUNCT__";
                push @consec_phrases, $next_anode->form;
            }
            push @consec_anodes, $next_anode;
            $covered_anodes{$next_anode->id} = 1;
            $next_anode = $next_anode->get_next_node;
        }

        push @collapsed_entities, [\@consec_ids, \@consec_phrases, \@consec_anodes];
    }

    return \@collapsed_entities;
}

sub get_delimiter_regex {
    my ($self) = @_;
    return '^[>]$';
}

sub get_entity_replacement_form {
    my ($self) = @_;
    return 'Menu';
}

sub _collapse_entity_anodes {
    my ($self, $atree, $entities) = @_;

    my @entity_anodes = ();

    foreach my $entity (@$entities) {
        my @anodes = sort {$a->ord <=> $b->ord} @{$entity->[2]};
        my $new_anode = $atree->create_child({
            form => $self->get_entity_replacement_form(),
        });
        $new_anode->wild->{gazeteer_entity_id} = $entity->[0];
        $new_anode->wild->{matched_item} = $entity->[1];

        $new_anode->shift_before_node($anodes[0]);
        push @entity_anodes, $new_anode;
        $_->remove() foreach (@anodes);
#        my $node_before = $new_anode->get_prev_node;
#        if (defined $node_before && ($node_before->form !~ /^the$|^a$|^an$/)) {
#            my $the_anode = $atree->create_child({
#                form => 'the',
#            });
#            $the_anode->shift_before_node($new_anode);
#        }
    }
    return \@entity_anodes;
}



1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::Block::W2A::EN::GazeteerMatch

=head1 DESCRIPTION

The block tries to find pre-defined sequences of words (phrases) in the surface text (word forms).
The list of phrases must be specified by the parameter C<phrase_list_path>. Typically, the list
of phrases is a part of a so-called gazetteer, which consists of two lists containing corresponding
phrases in two languages. The phrase list consist of to columns: 1) phrase identifier, 2) phrase itself.
The identifier column must be the same for both lists belonging to the same gazetteer.

This block performs on analytical trees, but must be applied on flat trees with all nodes being children
of the root, in fact representing just the sequence of tokens. The best place to apply this block is
just after tokenization.

In the initialization stage, the phrase list is loaded and structured in a word-based trie. The leafs
of the trie are the [phrase identifier, phrase] pairs whereas the inner nodes of the trie are lowercased
words contained in the stored phrases.

The block proceeds in multiple steps. First, the trie is used to match the phrases from the list
in the text, represented by the a-tree. Every match found consists of the phrase string, its identifier
and the sequence of a-nodes covered by the phrase.

Second, every matched phrase is assigned a score estimating the extent to which the phrase is a named
entity. This is done by the C<score_match> function, which depends on several factors, e.g. the language
and domain. Therefore, it can and should be overriden in subclasses. The matches with positive score
are ordered by the score and filtered to get non-overlapping matches, taking those with higher score first.

Third, the matched a-nodes belonging to a single entity collapsed into a single node. The replacement
form of the node can be specified by the C<get_entity_replacement_form> function.

As a last step, the neighbouring entities are collapsed into one and replaced by a single a-node, whose
form is again specified by the C<get_entity_replacement_form> function. The entities are collapsed also
when they are separated by a delimiter specified by a regular expression returned by the C<get_delimiter_regex>
function.

For the a-nodes that are in fact collapsed phrases, two special wild attributes are specified:
a sequence of phrase identifiers in C<gazeteer_entity_id> and the corresponding sequence of matched phrases
in the C<matched_item> wild attribute.

Note that it might be handy to alter the POS tag of the gazetteer entity found by this block later
after POS tagging and before parsing.

=head1 PARAMETERS

=head2 phrase_list_path

Path to a list of phrases to be matched.

=head2 filter_id_prefixes

One can limit the range of phrases a trie is filled with by setting the string which has to match with 
the prefix of phrase identifiers. A special (and default) value 'all' determines that no filtering is 
performed. More than one value can be specified, delimited by a comma.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

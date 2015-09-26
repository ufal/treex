package Treex::Tool::Gazetteer::Engine;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

has 'is_src' => (is => 'ro', isa => 'Bool', default => 1);
has 'path' => (is => 'ro', isa => 'Str', required => 1);
has 'filter_id_prefixes' => ( is => 'ro', isa => 'Str', default => 'all' );

has '_hash' => ( is => 'rw', isa => 'HashRef' );
has '_trie' => ( is => 'rw', isa => 'HashRef' );

sub BUILD {
    my ($self) = @_;

    if ($self->is_src) {
        $self->_set_trie($self->_build_trie);
    }
    else {
        $self->_set_hash($self->_build_hash);
    }
}

sub _build_trie {
    my ($self) = @_;

    log_info "Loading the phrase list...";
    log_info "Building a trie for searching...";

    my $path = require_file_from_share($self->path);
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

sub _build_hash {
    my ($self) = @_;

    log_info "Loading the target phrase list from ".$self->path." ...";

    my $path = require_file_from_share($self->path);
    open my $fh, "<:gzip:utf8", $path;

    my $hash = {};

    while (my $line = <$fh>) {
        chomp $line;
        my ($id, @phrase_rest) = split /\t/, $line;
        my $phrase = join " ", @phrase_rest;

        $hash->{$id} = $phrase;
    }
    close $fh;

    #log_info Dumper($searchine);

    return $hash;
}

sub match_phrases_in_atree {
    my ($self, $atree) = @_;
    
    my @anodes = $atree->get_children( {ordered => 1} );

    my @matches = ();
    my @unproc_trie_nodes = ();
    my @unproc_anodes = ();

    foreach my $anode (@anodes) {
        unshift @unproc_trie_nodes, $self->_trie;

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

sub get_phrase_by_id {
    my ($self, $id) = @_;
    if (!defined $self->_hash) {
        log_warn "Used as a target gazetteer list but created as a source one (is_src=1).";
    }
    return $self->_hash->{$id};
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Gazetteer::Engine - engine to work with gazetteers

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

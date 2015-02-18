package Treex::Block::W2A::CS::FixNELemmas;

use Moose;
use Treex::Core::Common;

use PerlIO::gzip;
use Tree::Trie;
use Text::Levenshtein qw/distance/;
use List::Util qw/min/;

extends 'Treex::Core::Block';

has 'ne_forms_path' => ( is => 'ro', isa => 'Str', default => 'data/models/ne_lemma_fix/cswiki.ne_forms.freq.txt.gz');
has '_ne_forms' => ( is => 'ro', isa => 'HashRef[Str]', builder => '_build_ne_forms', lazy => 1);

has 'wiki_titles_path' => ( is => 'ro', isa => 'Str', default => 'data/models/ne_lemma_fix/cswiki.titles.txt.gz');
has '_wiki_titles' => ( is => 'ro', isa => 'Tree::Trie', builder => '_build_wiki_titles', lazy => 1);

has 'suffix_change_threshold' => ( is => 'ro', isa => 'Num', default => 0.3 );

sub process_start {
    my ($self) = @_;
    $self->_ne_forms;
    $self->_wiki_titles;
}

sub _build_ne_forms {
    my ($self) = @_;

    my $ne_forms = {};

    my $path = require_file_from_share($self->ne_forms_path);
    log_info "Loading a list of NE forms from '$path'";
    open my $forms_fh, "<:gzip:utf8", $path or die $!;
    while (<$forms_fh>) {
        chomp $_;
        $_ =~ s/^\s*//;
        $_ =~ s/\s*$//;
        my ($count, $form) = split /\s+/, $_;
        my $cap_hash = $ne_forms->{lc($form)};
        if (defined $cap_hash) {
            $cap_hash->{$form} = $count;
        }
        else {
            $cap_hash = {};
            $cap_hash->{$form} = $count;
            $ne_forms->{lc($form)} = $cap_hash; 
        }
    }
    close $forms_fh;

    my $ne_forms_only = {};
    foreach my $key (keys %$ne_forms) {
        my $cap_hash = $ne_forms->{$key};
        my ($max_key) = sort {$cap_hash->{$b} <=> $cap_hash->{$a}} keys %$cap_hash;
        $ne_forms_only->{$key} = $max_key;
    }

    return $ne_forms_only;
}

sub _build_wiki_titles {
    my ($self) = @_;

    my $wt_trie = Tree::Trie->new();

    my $path = require_file_from_share($self->wiki_titles_path);
    log_info "Loading a list of Wikipedia titles from '$path'";
    open my $wt_fh, "<:gzip:utf8", $path;
    while (<$wt_fh>) {
        chomp $_;
        $wt_trie->add(lc($_));
    }
    close $wt_fh;
    return $wt_trie;
}

sub is_change_minor {
    my ($self, $old_word, $new_word, $dist) = @_;

    return ($dist / length($old_word)) < $self->suffix_change_threshold;
}

sub process_anode {
    my ( $self, $anode ) = @_;
    return if ( $anode->is_root );

    #return if (!defined $anode->n_node);
    #return if (lc($anode->form) eq $anode->form);

    # fix only those guessed by a lemmatizer
    return if (!$anode->wild->{lemma_guessed});
    log_info "LEMMA GUESSED: ".$anode->lemma;

    # fix only those nodes, whose lemma cannot be found in the list
    return if ($self->_ne_forms->{lc($anode->lemma)});
    log_info "LEMMA NOT FOUND: ".$anode->lemma;

    my $lc_form = lc($anode->form);
    
    my $wt = $self->_wiki_titles;
    $wt->deepsearch('prefix');
    my $longest_prefix = $wt->lookup($lc_form);
    return if (length($longest_prefix) == 0);
    log_info "LONGEST_PREFIX: $longest_prefix";
    
    my @possible_words = $wt->lookup($longest_prefix);
    log_info "POSSIBLE_WORDS: " . Dumper(@possible_words);
    my @distances = distance($lc_form, @possible_words);

    my $min_dist = min @distances;
    log_info "MIN_DIST: $min_dist";
    my ($new_lc_lemma) = @possible_words[(grep {$distances[$_] == $min_dist} 0 .. $#distances)];
    log_info "NEW LC LEMMA: $new_lc_lemma";

    return if (!$self->is_change_minor($lc_form, $new_lc_lemma, $min_dist));

    #if (defined $new_lemma) {
    my $new_lemma = $self->_ne_forms->{$new_lc_lemma};
    log_info "NEW LEMMA: $new_lemma";
    $anode->set_lemma($new_lemma);
    #}
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::CS::FixNELemmas

=head1 DESCRIPTION

An attempt to fix lemmas a lemmatizer assigned mostly to named entities (e.g. "Gmailus", "OpenOffika", "Wi-Fa")

=over

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

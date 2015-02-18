package Treex::Block::W2A::CS::FixGuessedLemmas;

use Moose;
use Treex::Core::Common;

use PerlIO::gzip;
use Tree::Trie;
#use Text::Levenshtein qw/distance/;
use Text::Brew;
use List::Util qw/min/;

extends 'Treex::Core::Block';

has 'forms_list_path' => ( is => 'ro', isa => 'Str', default => 'data/models/ne_lemma_fix/cswiki.forms.freq.txt.gz');
has '_forms_list' => ( is => 'ro', isa => 'HashRef[Str]', builder => '_build_forms_list', lazy => 1);

has 'lemmas_list_path' => ( is => 'ro', isa => 'Str', default => 'data/models/ne_lemma_fix/cswiki.titles.txt.gz');
has '_lemmas_list' => ( is => 'ro', isa => 'Tree::Trie', builder => '_build_lemmas_list', lazy => 1);

#has 'suffix_change_threshold' => ( is => 'ro', isa => 'Num', default => 0.3 );

sub process_start {
    my ($self) = @_;
    $self->_forms_list;
    $self->_lemmas_list;
}

sub _build_forms_list {
    my ($self) = @_;

    my $forms_freq = {};

    my $path = require_file_from_share($self->forms_list_path);
    log_info "Loading a list of forms not contained in the MorphoDiTa dictionary from '$path'";
    open my $forms_fh, "<:gzip:utf8", $path or die $!;
    while (<$forms_fh>) {
        chomp $_;
        $_ =~ s/^\s*//;
        $_ =~ s/\s*$//;
        my ($count, $form) = split /\s+/, $_;
        my $cap_hash = $forms_freq->{lc($form)};
        if (defined $cap_hash) {
            $cap_hash->{$form} = $count;
        }
        else {
            $cap_hash = {};
            $cap_hash->{$form} = $count;
            $forms_freq->{lc($form)} = $cap_hash; 
        }
    }
    close $forms_fh;

    my $forms_list = {};
    foreach my $key (keys %$forms_freq) {
        my $cap_hash = $forms_freq->{$key};
        my ($max_key) = sort {$cap_hash->{$b} <=> $cap_hash->{$a}} keys %$cap_hash;
        $forms_list->{$key} = $max_key;
    }

    return $forms_list;
}

sub _build_lemmas_list {
    my ($self) = @_;

    my $ll_trie = Tree::Trie->new();

    my $path = require_file_from_share($self->lemmas_list_path);
    log_info "Loading a list of lemmas not contained in the MorphoDiTa dictionary from '$path'";
    open my $ll_fh, "<:gzip:utf8", $path;
    while (<$ll_fh>) {
        chomp $_;
        $ll_trie->add(lc($_));
    }
    close $ll_fh;
    return $ll_trie;
}

sub is_change_minor {
    my ($self, $old_word, $new_word, $dist) = @_;

    #return ($dist / length($old_word)) < $self->suffix_change_threshold;
    return ($dist < 3);
}

sub distance {
    my ($str1, $str2) = @_;

    my ($dist, $edits) = Text::Brew::distance($str1, $str2);
    
    my $match_penalty = 1;
    my $weighted_dist = 0;
    foreach my $edit (reverse @$edits) {
        if ($edit eq 'INITIAL') {
            next;
        }
        elsif ($edit ne 'MATCH') {
            $weighted_dist += $match_penalty;
        }
        else {
            $match_penalty *= 2;
        }
    }
    return $weighted_dist;
}

sub process_anode {
    my ( $self, $anode ) = @_;
    return if ( $anode->is_root );

    #return if (!defined $anode->n_node);
    #return if (lc($anode->form) eq $anode->form);

    # fix only those guessed by a lemmatizer
    return if (!$anode->wild->{lemma_guessed});
#    log_info "LEMMA GUESSED: ".$anode->lemma;

    # fix only those nodes, whose guessed lemma cannot be found in the list
    return if ($self->_forms_list->{lc($anode->lemma)});
#    log_info "LEMMA NOT FOUND: ".$anode->lemma;
    
    my $lc_form = lc($anode->form);
#    log_info "LC_FORM: $lc_form";

    # fix only those whose form can be found in the list
    return if (!$self->_forms_list->{$lc_form});

    my $wt = $self->_lemmas_list;
    $wt->deepsearch('prefix');
    my $longest_prefix = $wt->lookup($lc_form);
    return if (!$longest_prefix);
#    log_info "LONGEST_PREFIX: $longest_prefix";
    
    my @possible_words = $wt->lookup($longest_prefix);
    my @distances = map {distance($lc_form, $_)} @possible_words;

    my $min_dist = min @distances;
#    log_info "MIN_DIST: $min_dist";
    my ($new_lc_lemma) = @possible_words[(grep {$distances[$_] == $min_dist} 0 .. $#distances)];
#    log_info "NEW LC LEMMA: $new_lc_lemma";

    return if (!$self->is_change_minor($lc_form, $new_lc_lemma, $min_dist));

    #if (defined $new_lemma) {
    my $new_lemma = $self->_forms_list->{$new_lc_lemma};
    return if (!defined $new_lemma);
#    log_info "NEW LEMMA: $new_lemma";
    $anode->set_lemma($new_lemma);
    #}
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::CS::FixGuessedLemmas

=head1 DESCRIPTION

An attempt to fix lemmas a lemmatizer (MorphoDiTa) has to guess and it often does it wrong (e.g. "Gmailus", "OpenOffika", "Wi-Fa").

It uses two lists extracted from the Czech Wikipedia:
a) forms list - a list of forms unseen in MorphoDiTa dictionary
    - the list, or rather a hash, is indexed by lowercased version of the word, its value is the most frequent truecased variant of this word
b) lemmas list - a list of lemmas unseen in MorphoDiTa dictionary
    - the list of lemmas
    - represented by a trie - to easily match the prefix
    - extracted from Wiki titles

This block is executed only on those a-nodes, whose form is not contained in MorphoDiTa dictionary, the guessed lemma is not 
contained in the forms list and, on the other hand, the form is contained in the forms list.
Then it tries to find a lemma from the lemmas list that is similar enough to the form (in terms of modified version of editing distance).

=over

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

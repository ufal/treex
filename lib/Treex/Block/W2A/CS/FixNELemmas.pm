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
        $ne_forms->{$form} = $count;
    }
    close $forms_fh;
    return $ne_forms;
}

sub _build_wiki_titles {
    my ($self) = @_;

    my $wt_trie = Tree::Trie->new();

    my $path = require_file_from_share($self->wiki_titles_path);
    log_info "Loading a list of Wikipedia titles from '$path'";
    open my $wt_fh, "<:gzip:utf8", $path;
    while (<$wt_fh>) {
        chomp $_;
        $wt_trie->add($_);
    }
    close $wt_fh;
    return $wt_trie;
}

sub process_anode {
    my ( $self, $anode ) = @_;
    return if ( $anode->is_root );

    # fix only NEs
    log_info "OLD LEMMA: ".$anode->lemma;
    #return if (!defined $anode->n_node);
    return if (lc($anode->form) eq $anode->form);
    log_info "OLD NE LEMMA: ".$anode->lemma;
    # fix only those nodes, whose lemma cannot be found in the list
    return if ($self->_ne_forms->{$anode->lemma});

    
    my $wt = $self->_wiki_titles;
    $wt->deepsearch('prefix');
    my $longest_prefix = $wt->lookup($anode->form);
    my @possible_words = $wt->lookup($longest_prefix);
    my @distances = distance($anode->form, @possible_words);

    my $min_dist = min @distances;
    my ($new_lemma) = @possible_words[(grep {$distances[$_] == $min_dist} 0 .. $#distances)];

    if (defined $new_lemma) {
        log_info "NEW LEMMA: $new_lemma";
        $anode->set_lemma($new_lemma);
    }
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

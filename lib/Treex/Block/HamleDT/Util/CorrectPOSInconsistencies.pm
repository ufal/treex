package Treex::Block::HamleDT::Util::CorrectPOSInconsistencies;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'trigrams_file' => ( is => 'rw', isa => 'Str', default => '' );
has 'corpus_file' => ( is => 'rw', isa => 'Str', default => '' );
has 'complexity' => ( is => 'rw', isa => 'Str', default => 'simple' );

use autodie;
use open qw( :std :utf8 );

my %variation_trigrams;
my %seen_nucleus_tags;
my @tagger_tags;

sub process_start {
    my $self = shift;

    open my $TRIGRAMS, '<:encoding(utf-8)', $self->trigrams_file;
    while ( defined( my $line = <$TRIGRAMS> )) {
        chomp $line;
        my ($nucleus, $tags, $tc, $trigram, $rest) = split "\t", $line, 5;
        $variation_trigrams{$trigram} = 1;
        my @nucleus_tags = split /\//, $tags;
        for my $nucleus_tag (@nucleus_tags) {
            $seen_nucleus_tags{$trigram}{$nucleus_tag} = 1;
        }
    }
    close $TRIGRAMS;

    open my $CORPUS, '<:encoding(utf-8)', $self->corpus_file;
    while ( defined( my $line = <$CORPUS> )) {
        chomp $line;
        my ($word, $tag) = split "\t", $line;
        if ($self->complexity eq 'complex') {
            if ($tag =~ /^</) {
                $tag =~ /,([^>]+)>/;
                $tag = $1;
            }
        }
        push @tagger_tags, $tag;
    }
    close $CORPUS;
}

sub process_atree {
    my $self = shift;
    my $a_root = shift;

    my @anodes = $a_root->get_descendants({ordered=>1});
    my @forms = map {$_->form()} @anodes;

    for my $i (1..$#anodes-1) {
        my $trigram = join ' ', @forms[$i-1..$i+1];
        if (defined $variation_trigrams{$trigram}) {
            my $tagger_tag = $tagger_tags[$i];
            my $old_tag = $anodes[$i]->get_iset_conll_feat();
            $old_tag =~ s/\|?tagset=[^|]*//g; # remove 'tagset' feature
            $old_tag =~ s/\|?other=[^|]*//g; # remove 'other' feature
            my $new_tag = $tagger_tag;
            my $msg;
            if ( $seen_nucleus_tags{$trigram}{$tagger_tag} ) {
                $msg = $old_tag eq $new_tag ? 'SAME' : 'DIFF';
            }
            else {
                $msg = 'INAPLICCABLE';
            }
            print $a_root->to_string(), "\n";
            print join(' ', @forms[0..$i-1], ">>> $forms[$i] <<<", @forms[$i+1..$#forms]), "\n";
            print join("\t", $msg, $forms[$i], "$old_tag -> $new_tag"), "\n\n";
        }
    }
    for my $j (0..$#anodes) {
        shift @tagger_tags;
    }
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Util::CorrectPOSInconsistencies

=head1 DESCRIPTION

Prints corrections of Interset based on variation ngrams and retagged corpus.

=head1 AUTHOR

Jan Mašek masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

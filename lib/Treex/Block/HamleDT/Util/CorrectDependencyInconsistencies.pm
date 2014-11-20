package Treex::Block::HamleDT::Util::CorrectDependencyInconsistencies;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'ngrams_file' => ( is => 'rw', isa => 'Str', default => '' );
has 'corpus_file' => ( is => 'rw', isa => 'Str', default => '' );
has 'sentence_number' => ( is => 'rw', isa => 'Int', default => 0, writer => 'set_sentence_number');

use List::Util 'all';
use autodie;
use open qw( :std :utf8 );

my @sentences;
my %ngrams;
my %ambiguity_classes;

sub process_start {
    my $self = shift;

    {
        open my $NGRAMS, '<:encoding(utf-8)', $self->ngrams_file;
        local $/ = "\n\n";
        while ( defined( my $paragraph = <$NGRAMS> )) {
            chomp $paragraph;
            my @lines = split "\n", $paragraph;
            my $bigram = shift @lines;
            for my $line (@lines) {
                my ($length, $ngram, @instances) = split "\t", $line;
                $ngram =~ s/\s+$//;
                for my $instance (@instances) {
                    my ($label, $sentence_number, @forms) = split / /, $instance;
                    my ($afun, $head_side) = split '-', $label;
                    $sentence_number = substr $sentence_number, 1;
                    my ($left_word_index, $right_word_index) = grep { $forms[$_] =~ /##/ } 0..$#forms;
                    my $parent_index = $head_side eq 'L' ? $left_word_index : $right_word_index;
                    $ngram =~ s/##.{15}//g;
                    push @{ $ngrams{$sentence_number} },
                        {
                            forms => $ngram,
                            left_word_index => $left_word_index,
                            right_word_index => $right_word_index,
                            afun => $afun,
                            head_side => $head_side,
                        };
                    $forms[$parent_index] =~ s/##.{15}//;
                    $ambiguity_classes{$ngram}{$afun} = $forms[$parent_index];
                }
            }
        }
        close $NGRAMS;
    }

    {
        open my $CORPUS, '<:encoding(utf-8)', $self->corpus_file;
        local $/ = '';
        @sentences = (undef, ); # empty sentence at index 0 to make indices correspond to sentence numbers
        while ( defined (my $paragraph = <$CORPUS>) ) {
            chomp $paragraph;
            my ($forms, $tags, $afuns, $parent_ords) = split "\n", $paragraph;
            my @forms = split "\t", $forms;
            my @afuns = split "\t", $afuns;
            my @parent_ords = split "\t", $parent_ords;
            my @sentence;
#            my %root = ( form => 'ROOT', afun => 'ROOT', parent_ord => '-' );
#            push @sentence, \%root;
            for my $i (0..$#forms) {
                my %word;
                $word{form} = $forms[$i];
                $word{afun} = $afuns[$i];
                $word{parent_ord} = $parent_ords[$i];
                push @sentence, \%word;
            }
            push @sentences, \@sentence;
        }
        close $CORPUS;
    }
    use Data::Dumper;
}

sub process_atree {
    my $self = shift;
    my $a_root = shift;

    $self->set_sentence_number( $self->sentence_number + 1 );

    if (exists $ngrams{$self->sentence_number}) {
        correct_sentence($self->sentence_number, $a_root);
    }
}

sub correct_sentence {
    my $sentence_number = shift;
    my $a_root = shift;

    my @anodes = $a_root->get_descendants({ordered=>1});
    my @sentence_forms = map {$_->form()} @anodes;

    for my $ngram (@{ $ngrams{$sentence_number} }) {
        my $ngram_forms = $ngram->{forms};
        my @ngram_forms = split ' ', $ngram_forms;
        my $ngram_length = scalar @ngram_forms;
        my $ngram_lwi = $ngram->{left_word_index};
        my $left_word = $ngram_forms[$ngram_lwi];
        my $ngram_rwi = $ngram->{right_word_index};
        my %ngram_ambiguity_class = %{ $ambiguity_classes{$ngram_forms} };

        my @possible_sentence_lwi = grep { $sentence_forms[$_] eq $left_word } 0..$#sentence_forms;
        my @possible_first_indexes = grep { $_ + $ngram_length -1 <= $#sentence_forms } map { $_ - $ngram_lwi } @possible_sentence_lwi;
        my @true_first_indexes = grep { $ngram_forms eq join(' ', @sentence_forms[$_..$_+$ngram_length-1]) } @possible_first_indexes;

        for my $i (@true_first_indexes) {

            # how it is in the corpus
            my $lwi = $ngram_lwi + $i;
            my $rwi = $ngram_rwi + $i;
            my ($corpus_parent_index, $corpus_child_index) = $ngram->{head_side} eq 'L' ? ($lwi, $rwi) : ($rwi, $lwi);
            my ($corpus_parent, $corpus_child) = map { $_->form() } @anodes[$corpus_parent_index, $corpus_child_index];
            my $corpus_afun = $ngram->{afun};

            # how it is in the parser output
            my @sentence = @{ $sentences[$sentence_number] };
            my $word = $sentence[$corpus_child_index];
            my $parser_afun = $word->{afun};
            my $parser_parent_ord = $word->{parent_ord};
            my $parser_parent_index = $parser_parent_ord - 1;
            my $parser_parent = $sentence[$parser_parent_index]->{form};

            my ($new_afun, $new_parent, $new_parent_index);
            my ($msg, $msg_afun, $msg_parent);

            my $true_corpus_parent_index = $anodes[$corpus_child_index]->parent()->ord() - 1;
            my $true_corpus_parent = $sentence[$true_corpus_parent_index]->{form};
            my $true_corpus_afun = $anodes[$corpus_child_index]->afun();

            # the correction itself
            # there is a real edge between the child and the parent
            if ($corpus_afun ne 'NIL') {
                # the parser-suggested new edge is in the ambiguity class - we accept it
                if ( ($ngram_ambiguity_class{$parser_afun} // '') eq $parser_parent ) {
                    $msg_afun = $corpus_afun eq $parser_afun ? 'SAME AFUN' : 'DIFF AFUN';
                    $msg_parent = $corpus_parent_index eq $parser_parent_index ? 'SAME PAR.' : 'DIFF PAR.';
                    $new_afun = $parser_afun;
                    $new_parent = $parser_parent;
                    $new_parent_index = $parser_parent_index;
                }
                # the parser-suggested new edge is NOT in the ambiguity class - we keep what is in the corpus
                else {
                    $msg_afun = 'INAPLICCABLE';
                    $msg_parent = 'INAPLICCABLE';
                    $new_afun = $parser_afun;
                    $new_parent = $parser_parent;
                    $new_parent_index = $parser_parent_index;
                }
            }
            # there is a NIL-(pseudo)edge between the child and the parent
            else {
                # the parser-suggested edge is in the ambiguity class
                if ( ($ngram_ambiguity_class{$parser_afun} // '') eq $parser_parent) {
                    # and its parent is the same as the real one in the corpus
                    if ($parser_parent_index eq $true_corpus_parent_index) {
                        $msg_afun = $parser_afun eq $true_corpus_afun ? 'SAME AFUN' : 'DIFF AFUN';
                        $msg_parent = 'SAME PAR.';
                        $new_parent_index = $true_corpus_parent_index;
                        $new_parent_index = $true_corpus_parent_index;
                    }
                    # its parent is a different one
                    else {
                        $msg_afun = $parser_afun eq $true_corpus_afun ? 'SAME AFUN' : 'DIFF AFUN';
                        $msg_parent = 'DIFF PAR.';
                        $new_parent_index = $parser_parent_index;
                    }
                    $new_afun = $parser_afun;
                }
                # the parser-suggested edge is not in the ambiguity class
                else {
                    $new_afun = $parser_afun;
                    $new_parent_index = $parser_parent_index;
                    $msg_afun = 'INAPLICCABLE';
                    $msg_parent = 'INAPLICCABLE';
                }
            }

            my $sentence_to_print;
            if ($corpus_parent_index == $new_parent_index) {
                $sentence_to_print = join(' ', @sentence_forms[0..$lwi-1], ">>> $sentence_forms[$lwi] <<<", @sentence_forms[$lwi+1..$rwi-1], ">>> $sentence_forms[$rwi] <<<", @sentence_forms[$rwi+1..$#sentence_forms]);
            }
            else {
                my ($i_1, $i_2, $i_3) = sort { $a <=> $b } ($lwi, $rwi, $new_parent_index);
                $sentence_to_print = join(' ', @sentence_forms[0..$i_1-1], ">>> $sentence_forms[$i_1] <<<", @sentence_forms[$i_1+1..$i_2-1], ">>> $sentence_forms[$i_2] <<<", @sentence_forms[$i_2+1..$i_3-1], ">>> $sentence_forms[$i_3] <<<", @sentence_forms[$i_3+1..$#sentence_forms]);
            }

            $msg = $msg_afun . ' ' . $msg_parent;

            print $a_root->to_string(), "\n";
            print $sentence_to_print, "\n";
            print join("\t", $msg, $corpus_child . '.' . $corpus_afun . ' -- ' . $corpus_parent,  "->", $corpus_child . '.' . $new_afun . ' -- ' . $sentence_forms[$new_parent_index]), "\n";
            print $msg_afun, "\t", $corpus_afun, " -> ", $new_afun, "\n";
            print $msg_parent, "\t",  $corpus_parent, " -> ", $sentence_forms[$new_parent_index], "\n";
            print "\n";
        }
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

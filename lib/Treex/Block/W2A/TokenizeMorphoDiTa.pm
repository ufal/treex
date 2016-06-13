package Treex::Block::W2A::TokenizeMorphoDiTa;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TokenizeOnWhitespace';
use Ufal::MorphoDiTa;

has '+language' => ( required => 1 );

# Instance of Ufal::MorphoDiTa::Tokenizer
has tool => (is=>'ro', lazy_build=>1);

sub _build_tool {
    my ($self) = @_;
    my $tool;
    if ($self->language eq 'en') {
        $tool = Ufal::MorphoDiTa::Tokenizer::newEnglishTokenizer();
    } elsif ($self->language eq 'cs') {
        $tool = Ufal::MorphoDiTa::Tokenizer::newCzechTokenizer();
    } else {
        $tool = Ufal::MorphoDiTa::Tokenizer::newGenericTokenizer();
    }
    return $tool;
}

sub process_start {
    my ($self) = @_;
    # The tool is lazy_build, so load it now
    $self->tool;
    return;
}

# the actual tokenize function which tokenizes one input string
# input: one string
# return: the tokenized string for the input string
override 'tokenize_sentence' => sub {
    my ($self, $sentence) = @_;

    $self->tool->setText($sentence);
    my $forms_object = Ufal::MorphoDiTa::Forms->new();
    my $tokens_object = Ufal::MorphoDiTa::TokenRanges->new();
    if ($self->tool->nextSentence($forms_object, $tokens_object)) {
        my @forms;
        for (my $i = 0; $i < $forms_object->size(); $i++) {
            push @forms, $forms_object->get($i);
        }
        return join ' ', @forms;
    } else {
        log_warn "Could not tokenize: $sentence";
        return $sentence;
    }
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TokenizeMorphoDiTa - MorphoDiTa tokenizer.

=head1 DESCRIPTION

Treex wrapper of the MorphoDiTa tokenizer.

Uses a language-specific tokenizer if language is C<cs> or C<en>, otherwise uses a generic tokenizer.

=head1 METHODS

=over

=item language

Required. Influences the nonbreaking prefixes file to be loaded.

=back

=head1 SEE ALSO

L<http://ufal.mff.cuni.cz/morphodita>

L<https://metacpan.org/pod/Ufal::MorphoDiTa>

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


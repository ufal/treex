package Treex::Tool::Tagger::MorphoDiTa;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
with 'Treex::Tool::Tagger::Role';

# This block terminates Tagger::MorphoDiTa and any other dependent modules, if Ufal::MorphoDiTa is not installed
# We want to include this wrapper into Treex-Unilang package, but remove the hard dependency on Ufal::MorphoDiTa package
# TODO: solve this problem in a better (more Treex-like) way
eval {
    require Ufal::MorphoDiTa;
    1;
};
if (my $dep = $@) {
    log_warn('missing module: Ufal::MorphoDiTa');
    exit 0;
}


# Path to the model data file
has model => ( is => 'ro', isa => 'Str', required => 1 );
has _model_absolute_path => ( is => 'ro', isa => 'Str', lazy_build => 1 );

sub _build__model_absolute_path {
    my ($self) = @_;
    return Treex::Core::Resource::require_file_from_share($self->model);
}

# Instance of Ufal::MorphoDiTa::Tagger
has tool  => (is=>'ro', lazy_build=>1);

# tool can be shared by more instances (if the dictionary file is the same)
my %TOOL_FOR_PATH;
sub _build_tool {
    my ($self) = @_;
    my $path = $self->_model_absolute_path;
    my $tool = $TOOL_FOR_PATH{$path};
    return $tool if $tool;
    log_info("Loading Ufal::MorphoDiTa::Tagger with model '$path'");
    $tool = Ufal::MorphoDiTa::Tagger::load($path)
        or log_fatal("Cannot load Ufal::MorphoDiTa::Tagger with model from file '$path'");
    $TOOL_FOR_PATH{$path} = $tool;
    return $tool;
}

sub BUILD {
    my ($self) = @_;
    # The tool is lazy_build, so load it now
    $self->tool;
    return;
}

sub tag_sentence {
    my ( $self, $tokens_rf ) = @_;
    my $forms = Ufal::MorphoDiTa::Forms->new();
    $forms->push($_) for @$tokens_rf;

    # The main work. Tags and lemmas will be saved to $tagged_lemmas.
    my $tagged_lemmas = Ufal::MorphoDiTa::TaggedLemmas->new();
    $self->tool->tag($forms, $tagged_lemmas);

    # Extract the result into @tags and @lemmas.
    my (@tags, @lemmas);
    for my $i (0 .. $tagged_lemmas->size()-1){
        my $tag_and_lemma = $tagged_lemmas->get($i);
        push @tags, $tag_and_lemma->{tag};
        push @lemmas, $tag_and_lemma->{lemma};
    }

    return (\@tags, \@lemmas);
}

sub is_guessed {
    my ($self, $tokens_rf) = @_;
    my $tagged_lemmas = Ufal::MorphoDiTa::TaggedLemmas->new();
    my $morpho = $self->tool->getMorpho();
    my @guessed = map {$morpho->analyze($_, $Ufal::MorphoDiTa::Morpho::GUESSER, $tagged_lemmas)} @$tokens_rf;
    return \@guessed;
}

1;

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::MorphoDiTa - wrapper for Ufal::MorphoDiTa

=head1 SYNOPSIS

 use Treex::Tool::Tagger::MorphoDiTa;
 my $tagger = Treex::Tool::Tagger::MorphoDiTa->new(
    model => 'data/models/morphodita/cs/czech-morfflex-pdt-131112.tagger-fast',
 );
 # or czech-morfflex-pdt-131112.tagger-best_accuracy
 my @tokens = qw(Jak to jde ?);
 my ($tags_rf, $lemmas_rf) = $tagger->tag_sentence(\@tokens);

=head1 DESCRIPTION

Wrapper for state-of-the-art part-of-speech (morphological) tagger MorphoDiTa
by Milan Straka and Jana Straková.

=head1 PARAMETERS

=over

=item model

Path to the model file within Treex share
(or relative path starting with "./" or absolute path starting with "/").

=back

=head1 METHODS

=over

=item ($tags_rf, $lemmas_rf) = $tagger->tag_sentence(\@tokens);

Returns a list of tags and lemmas for tokenized input.

=back

=head1 SEE ALSO

L<http://ufal.mff.cuni.cz/morphodita>

L<https://metacpan.org/pod/Ufal::MorphoDiTa>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
The development of this resource is partly funded by the European Commision, project QTLeap FP7-ICT-2013.4.1-610516 L<http://qtleap.eu>

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

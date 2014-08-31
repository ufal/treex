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
has model => ( is => 'ro', isa => 'Str', required => 1, writer => '_set_model' );

# Instance of Ufal::MorphoDiTa::Tagger
has '_tagger' => ( is=> 'rw');

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    my $model_file = Treex::Core::Resource::require_file_from_share($self->model);
    $self->_set_model($model_file);
    log_info("Loading Ufal::MorphoDiTa tagger with model '$model_file'");
    my $tagger = Ufal::MorphoDiTa::Tagger::load($model_file)
        or log_fatal("Cannot load Ufal::MorphoDiTa::Tagger with model from file '$model_file'");
    #log_info('Done.');
    $self->_set_tagger($tagger);
    return;
}

sub tag_sentence {
    my ( $self, $tokens_rf ) = @_;
    my $forms  = Ufal::MorphoDiTa::Forms->new();
    $forms->push($_) for @$tokens_rf;

    # The main work. Tags and lemmas will be saved to $tagged_lemmas.
    my $tagged_lemmas = Ufal::MorphoDiTa::TaggedLemmas->new();
    $self->_tagger->tag($forms, $tagged_lemmas);

    # Extract the result into @tags and @lemmas.
    my (@tags, @lemmas);
    for my $i (0 .. $tagged_lemmas->size()-1){
        my $tag_and_lemma = $tagged_lemmas->get($i);
        push @tags, $tag_and_lemma->{tag};
        push @lemmas, $tag_and_lemma->{lemma};
    }
    return (\@tags, \@lemmas);
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

Path to the model file within Treex share.

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

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

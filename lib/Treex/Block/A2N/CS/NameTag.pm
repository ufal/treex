package Treex::Block::A2N::CS::NameTag;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
extends 'Treex::Block::A2N::NameTag';

has '+model' => ( default => 'data/models/nametag/cs/czech-cnec2.0-140304.ner' );

# override the default concatenation of lemmas with truncation to "raw" lemmas
sub guess_normalized_name {
    my ($self, $entity_anodes_rf, $type) = @_;
    return join ' ', map {
        my $lemma = $_->lemma // $_->form; #/# use wordforms if lemmatizer was not applied
        $lemma = Treex::Tool::Lexicon::CS::truncate_lemma($lemma , 1 );
        $lemma = ucfirst $lemma if $type =~ /^[pP]/;
        $lemma;
    } @$entity_anodes_rf;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2N::CS::NameTag - Czech named entity recognizer NameTag

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::A2N::NameTag> which adds the path to the
default model for Czech and filling "raw" lemmas into the C<normalized_name>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

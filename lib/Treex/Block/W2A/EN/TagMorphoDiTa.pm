package Treex::Block::W2A::EN::TagMorphoDiTa;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TagMorphoDiTa';

has '+model' => ( default => 'data/models/morphodita/en/english-morphium-wsj-140407.tagger' );

has 'negative_prefixes_in_lemma' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'Some English MorphoDiTa models lemmatize words with negative prefixes'
                   . ' e.g. as "unable"->"able^un". Do we want to have such lemmas? Default is false.',
);


after 'process_atree' => sub {
    my ($self, $atree) = @_;
    if ($self->lemmatize && $self->model !~ /no_negation.tagger$/ && !$self->negative_prefixes_in_lemma){
        foreach my $anode ($atree->get_descendants()){
            my ($lemma, $prefix) = split /\^/, $anode->lemma;
            if (defined $prefix){
                $anode->set_lemma($lemma);
                $anode->set_iset(negativeness => 'neg');
            }
        }
    }
    return;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::TagMorphoDiTa

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::W2A::TagMorphoDiTa> which adds the path to the
default model for English.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

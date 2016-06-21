package Treex::Block::W2A::DE::LemmatizeMate;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Mate::Run;

has model_file => (
    is          => 'rw',
    isa         => 'Str',
    default     => "lemma-ger-3.6.model"
);

has lemmatizer => ( is => 'rw' );

sub process_start {
    my ($self) = @_;

    my $lemmatizer = Treex::Tool::Mate::Run->new(
        language => $self->language,
        selector => $self->selector,
        model => $self->model_file,
        classpath => "transition-1.30.jar",
        classname => "is2.lemmatizer2.Lemmatizer"
    );
    $self->set_lemmatizer( $lemmatizer );

    return;
}

sub process_document {
    my ( $self, $doc ) = @_;

    $self->lemmatizer->process_document($doc);
}

#sub process_zone {
#    my ( $self, $zone ) = @_;
#
#    my $sentence = $zone->sentence;
#
#    my $a_root;
#    if ($zone->has_atree) {
#        $a_root = $zone->get_atree();
#    }
#    else {
#        $a_root = $zone->create_atree();
#        my $ord = 1;
#
#        # We assume, that the sentence was already tokenized
#        foreach my $token (split / /, $sentence) {
#            $a_root->create_child( form => $token, ord => $ord );
#            $ord++;
#        }
#    }
#    $self->lemmatizer->process_sentence($a_root);
#
#    return 1;
#}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::DE::LemmatizeMate - lemmatization using the mateplus Lemmatizer

=head1 DESCRIPTION

# TODO

=head1 ATTRIBUTES

=over 2

=item model_file

=item lemmatizer

=back

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


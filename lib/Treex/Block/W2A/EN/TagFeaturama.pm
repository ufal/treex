package Treex::Block::W2A::EN::TagFeaturama;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::Tag';
use Treex::Tool::Tagger::Featurama::EN;

sub _build_tagger{
    return Treex::Tool::Tagger::Featurama::EN->new;
}

sub BUILD {
    my ($self, $arg_ref) = @_;
    log_fatal 'English Featurama does not support lemmatization' if $arg_ref->{lemmatize};
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::TagFeaturama - English PoS tagger

=head1 DESCRIPTION

Each node in the analytical tree is tagged using the L<Treex::Tool::Tagger::Featurama|Featurama> tagger.
Lemmatization is not supported for English.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

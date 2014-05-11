package Treex::Block::W2A::CS::TagFeaturama;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::Tag';

sub _build_tagger{
    return Treex::Tool::Tagger::Featurama::CS->new;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::CS::TagFeaturama - Czech PoS+morpho tagger

=head1 DESCRIPTION

Each node in the analytical tree is tagged using the L<Treex::Tool::Tagger::Featurama|Featurama> tagger.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

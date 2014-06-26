package Treex::Block::T2A::PT::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::InitMorphcat';

sub should_fill {
    my ($self, $grammateme, $tnode) = @_;

    # In Portuguese, nouns are not marked with definiteness on the a-layer.
    # T2A::PT::AddArticles will add an article for this grammateme.
    return 0 if $grammateme eq 'definiteness';

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::InitMorphcat

=head1 DESCRIPTION

Fill Interset morphological categories with values derived from grammatemes and formeme.

=head1 SEE ALSO

L<Treex::Block::T2A::InitMorphcat>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

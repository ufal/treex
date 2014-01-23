package Treex::Block::T2A::CS::AddAppositionPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddAppositionPunct';

use Treex::Tool::Lexicon::CS::PersonalRoles;
use Treex::Tool::Lexicon::CS::NamedEntityLabels;

override 'is_apposition' => sub {
    my ( $self, $tnode, $parent ) = @_;

    return (
        $tnode->formeme eq 'n:attr'
            and $parent->precedes($tnode) and !$parent->is_root
            and $parent->formeme =~ /^n/
            and ( $tnode->gram_sempos || '' ) eq 'n.denot'    # not numerals etc.
            and (
            Treex::Tool::Lexicon::CS::PersonalRoles::is_personal_role( $tnode->t_lemma )
            || Treex::Tool::Lexicon::CS::NamedEntityLabels::is_label( $tnode->t_lemma )
            )
    );
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::AddAppositionPunct

=head1 DESCRIPTION

Add commas in apposition constructions such as "John, my best friend, ...".

This language-specific module just detects appositions in Czech, the actual
adding of commas is implemented in L<Treex::Block::T2A::AddAppositionPunct>. 

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

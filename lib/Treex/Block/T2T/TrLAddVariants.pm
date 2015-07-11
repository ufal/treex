package Treex::Block::T2T::TrLAddVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::TrLAddVariantsInterpol';
with 'Treex::Block::T2T::TrAddVariantsRole';

has '+discr_weight' => ( default => 1.0 );
has '+static_weight' => ( default => 0.5 );

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrLAddVariants -- add t-lemma translation variants from translation models (language-independent)

=head1 DESCRIPTION

Adding t-lemma translation variants. The selection of variants
is based on the discriminative (discr) and the dictionary (static) model.

This block uses a combination of translation models to predict log-probabilities of t-lemma translation
variants.

The available models are Maximum Entropy (using L<AI::MaxEnt>), Static (based on simple corpus counts).

Using L<Treex::Tool::Memcached::Memcached> models is enabled via the 
L<Treex::Block::T2T::TrUseMemcachedModel> role.  

See the 'documentation' parameter of the individual attributes for details on various options.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::PT::AddPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddPrepos';

# In Portuguese, it seems adverbs may have prepositions as well (e.g. "por ali").
has '+formeme_prep_regexp' => ( default => '^(?:n|adj|adv):(.+)[+]' );

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::PT::AddPrepos

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.
In Portuguese, it seems adverbs may have prepositions as well (e.g. "por ali").

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

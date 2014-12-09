package Treex::Block::T2A::NL::AddPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddPrepos';

# In Portuguese, it seems adverbs may have prepositions as well (e.g. "tot dan toe").
has '+formeme_prep_regexp' => ( default => '^(?:n|adj|adv):(.+)[+]' );

override 'postprocess' => sub {
    my ( $self, $tnode, $anode, $prep_forms_string, $prep_nodes ) = @_;

    if ( $prep_nodes->[-1]->form =~ /^(toe|geleden)$/ ) {        
        $prep_nodes->[-1]->shift_after_subtree($anode, {without_children=>1});
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddPrepos

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.

In Dutch, it seems adverbs may have prepositions as well (e.g. "tot dan toe", "zoals tot dusverre").
Also a few postpositions are handled ("toe", "geleden").

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

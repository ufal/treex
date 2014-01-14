package Treex::Block::T2A::EN::AddPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddPrepos';

override 'get_prep_forms' => sub {
    my ( $self, $formeme ) = @_;
    return undef if ( !$formeme );
    my ($prep_forms) = ( $formeme =~ /(?:n|adj):(.+)\+/ );
    return $prep_forms if ($prep_forms);
    ($prep_forms) = ( $formeme =~ /v:(.+)\+ger/ );
    return $prep_forms;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddPrepos

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.

English-specific: adding prepositions to gerunds. 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

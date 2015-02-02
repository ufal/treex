package Treex::Block::T2A::NL::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubconjs';


override 'get_subconj_forms' => sub {
    my ( $self, $formeme ) = @_;
    return undef if (!$formeme);
    $formeme =~ s/^v:(predc|subj|obj)/v/;
    my ($subconj_forms) = ( $formeme =~ /^v:(.+)\+fin$/ );
    return $subconj_forms;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddSubconjs

=head1 DESCRIPTION

Add a-nodes corresponding to subordinating conjunctions
(according to the corresponding t-node's formeme).


=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

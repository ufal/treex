package Treex::Block::T2T::EN2EU::FixYouPl;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $tnode ) = @_;

    if (($tnode->gram_sempos || "") =~ 'n.pron' &&
	($tnode->gram_person || "") eq '2') {
	$tnode->set_attr("gram/number", 'nr');
    }
    
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2EU::FixYouPl

=head1 DESCRIPTION

Some 'you' pronouns has plural analysis. It should be 'nr'

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

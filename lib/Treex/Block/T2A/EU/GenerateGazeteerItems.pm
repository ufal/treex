package Treex::Block::T2A::EU::GenerateGazeteerItems;
use Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;
    my $anode = $tnode->get_lex_anode();

    return if (! $anode);

    if (($tnode->t_lemma_origin || "") eq "lookup-TrGazeteerItems") {
	$anode->set_form($anode->lemma);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::GenerateGazeteerItems

=head1 DESCRIPTION

Gazeteer items should be treat as Proper names, which are not (usually) flexioned

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

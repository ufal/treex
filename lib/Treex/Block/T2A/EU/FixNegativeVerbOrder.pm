package Treex::Block::T2A::EU::FixNegativeVerbOrder;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();

    return if ((!$anode) || ($anode->iset->pos || "") ne "verb");

    my @neg_nodes = grep {($_->lemma || "") eq "ez"} $anode->get_children();
    return if ($#neg_nodes == -1);

    my $neg = pop @neg_nodes;
    

    my ($obj) = grep {($_->formeme || "") =~ /:(\[abs\]\+X|obj)$/} $tnode->get_children({preceding_only => 1});
    my ($subj) = grep {($_->formeme || "") =~ /:(\[erg\]\+X|subj)$/} $tnode->get_children({preceding_only => 1});

    if ($obj && $subj) {
	$neg->shift_before_subtree($obj->get_anodes({first_only=>1}));
    }

    $anode->shift_after_node($neg, {without_children=>1});
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::

=head1 DESCRIPTION

Negative verbs should be placed in a different order "patatak jan ditut" -> "ez ditut patatak jan""

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

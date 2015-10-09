package Treex::Block::W2A::EU::FixModalVerbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my @MODAL = ("nahi", "ahal", "ezin", "behar");
#my @MODAL = ("nahi", "gura", "gogo", "ahal", "ezin", "behar", "ari");

sub process_anode {
    my ($self, $anode) = @_;

    if (grep {$anode->lemma eq $_} @MODAL) {
	my $parent = $anode->get_parent();
	return 1 if ($parent->is_root);

	my @children = grep {$_->is_verb} $anode->get_children();
	if ($#children >= 0) {
	    $children[0]->set_parent($parent->get_parent());

	    #rehang all nodes from parent bellow the main verb
	    $parent->set_parent($children[0]);
	    $parent->set_afun('AuxV');

	    #rehang all nodes from the modal verb bellow the main verb
	    $anode->set_parent($children[0]);
	    $parent->set_afun('AuxV');
	}
    }

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EU::

=head1 DESCRIPTION

Fix the analysis of several modal verbs

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

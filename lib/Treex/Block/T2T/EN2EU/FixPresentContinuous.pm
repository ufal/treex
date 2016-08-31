package Treex::Block::T2T::EN2EU::FixPresentContinuous;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $src_tnode = $tnode->src_tnode;
    
    my $tense = $src_tnode->wild->{tense} or return;
    if ((defined $tense->{cont})) {
    
	my ($anode) = grep {$_->lemma eq "be"} $src_tnode->get_aux_anodes();

	if (!$anode) {
	    delete $tense->{cont};
	    $src_tnode->wild->{tense} = $tense;
	}
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2EU::FixThereIs

=head1 DESCRIPTION

Some English forms are incorrectly marked as present continuous. Try to correct them.

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

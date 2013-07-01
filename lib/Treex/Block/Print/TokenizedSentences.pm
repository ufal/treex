package Treex::Block::Print::TokenizedSentences;
use Treex::Core::Common;
use Moose;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.txt' );

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );
	my @forms = map{$_->form}@nodes;
	my $sentence = join(" ", @forms);
	print { $self->_file_handle } $sentence, "\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::TokenizedSentences - Prints tokenized sentences.

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
package Treex::Block::T2T::EN2EU::RemoveRelPron;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $parent = $t_node->get_parent();


    if ($t_node->t_lemma eq "that" and $parent->formeme =~ /^v:rc/) {
	$t_node->set_t_lemma("#PersPron");
	$t_node->set_t_lemma_origin('RemoveRelPron');
    }

}
1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2EU::RemoveRelPron;

=head1 DESCRIPTION


=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2T::EN2EU::TranslateRelPron;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $parent = $t_node->get_parent();
    
    return if ($t_node->formeme !~ /^v:rc/);
    
    $t_node->set_formeme("v:[erl]+rc");
    $t_node->set_formeme_origin('RemoveRelPron');

    my $child;
    if (($child) = grep {$_->t_lemma eq "that"} $t_node->get_children()) {
	$child->set_t_lemma("#PersPron");
	$child->set_t_lemma_origin('RemoveRelPron');
    }
    elsif (($child) = grep {$_->t_lemma eq "where"} $t_node->get_children()) {
	$child->set_formeme('n:[ine]+X');
	$child->set_formeme_origin('RemoveRelPron');
	$child->set_t_lemma('toki');
	$child->set_attr( 'mlayer_pos', 'noun');
	$child->set_t_lemma_origin('RemoveRelPron');
	$child->set_parent($parent);
	$t_node->set_parent($child);
	$parent=$child;
    }

    $t_node->shift_before_node($parent);

    return;
}
1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2EU::TranslateRelPron;

=head1 DESCRIPTION

Translates different types of relative pronouns: Removes presonal pronuns and translates "where" as "-en tokian"

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

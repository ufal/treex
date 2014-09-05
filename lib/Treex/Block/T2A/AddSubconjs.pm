package Treex::Block::T2A::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $subconj_forms_str = $self->get_subconj_forms($t_node->formeme);
    return if (!$subconj_forms_str);

    # multiword conjunctions or conjunctions with expletives (pote co) are possible
    my @subconj_forms = split /_/, $subconj_forms_str;

    my $a_node = $t_node->get_lex_anode();

    my ( $first_subconj_node, $prev_subconj_node );
    my (@subconj_nodes) = ();

    foreach my $subconj_form (@subconj_forms) {

        my $subconj_node = $a_node->get_parent()->create_child(
            {   'form'         => $subconj_form,
                'lemma'        => $subconj_form,
                'afun'         => 'AuxC',
                'morphcat/pos' => 'J',
            }
        );
        $subconj_node->iset->add(pos=>'conj', conjtype=>'sub');
        push @subconj_nodes, $subconj_node;

        # hang the first subconj node above the clause
        if ( not $first_subconj_node ) {
            $subconj_node->shift_before_subtree($a_node);
            $a_node->set_parent($subconj_node);
            $first_subconj_node = $subconj_node;
            $prev_subconj_node  = $subconj_node;

            # move the is_member attribute to the conjunction
            $subconj_node->set_is_member( $a_node->is_member );
            $a_node->set_is_member();
        }

        # hang all other parts of a compound subconj under the first part
        else {
            $subconj_node->set_parent($first_subconj_node);
            $subconj_node->shift_after_node($prev_subconj_node);
            $prev_subconj_node = $subconj_node;
        }

        $t_node->add_aux_anodes($subconj_node);
    }

    $self->postprocess( $t_node, $a_node, \@subconj_nodes );

    return;
}

sub postprocess {
    my ($t_node, $a_node, $subconj_nodes) = @_;
    return;
}

sub get_subconj_forms {
    my ( $self, $formeme ) = @_;
    return undef if (!$formeme);
    my ($subconj_forms) = ( $formeme =~ /^v:(.+)\+/ );
    return $subconj_forms;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSubconjs

=head1 DESCRIPTION

Add a-nodes corresponding to subordinating conjunctions
(according to the corresponding t-node's formeme).

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2T::EN::FixApps;
use Moose;
use Treex::Core::Common;

use List::MoreUtils qw/any/;

extends 'Treex::Core::Block';

sub _is_subtree_mbr2 {
    my ($anode) = @_;
    return 0 if ($anode->afun ne "Atr");
    return 0 if ($anode->tag !~ /^N/);
    return 0 if ($anode->tag =~ /^NNP/);
    return 1;
}

sub process_tnode {
    my ($self, $mbr1_tnode) = @_;
    my $mbr1_anode = $mbr1_tnode->get_lex_anode;

    # the first member of an apposition must be a noun
    return if (!defined $mbr1_anode);
    return if ($mbr1_anode->tag !~ /^N/);

    # its child must be a comma
    my ($first_comma_anode, @other_commas) = grep {$_->form eq ','} $mbr1_anode->get_children;
    return if (!defined $first_comma_anode);

    # find the head node of the second member of the apposition
    # it must be a child of the first member in the original atree
    my $mbr2_anode = $first_comma_anode->get_next_node;
    while (!$mbr2_anode->is_root && $mbr2_anode->get_parent != $mbr1_anode) {
        $mbr2_anode = $mbr2_anode->get_parent;
    }
    return if ($mbr2_anode->is_root);

    log_info "Processing node " . $mbr1_tnode->id;

    # must be hung to the first member as an attribute
    if ($mbr2_anode->is_coap_root) {
        return if (any {!_is_subtree_mbr2($_)} $mbr2_anode->get_coap_members);

    }
    elsif (!_is_subtree_mbr2($mbr2_anode)) {
        return;
    }

    my ($mbr2_tnode) = $mbr2_anode->get_referencing_nodes('a/lex.rf');
    if (!defined $mbr2_tnode) {
        log_warn "A lex anode should be defined to " . $mbr2_anode->get_address;
        return;
    }

    # create APPS node and fix ttree topography

    log_info "Adding APPS for " . $mbr1_tnode->get_address;

    my $apps_tparent = $mbr1_tnode->get_parent;
    my $apps_tnode = $apps_tparent->create_child({
        t_lemma => '#Comma',
        functor => 'APPS',
        formeme => 'x',
        nodetype => 'coap',
    });
    if ($apps_tparent->is_coap_root) {
        $apps_tnode->set_is_member(1);
    }
    $apps_tnode->shift_before_subtree($mbr2_tnode);
    $mbr1_tnode->set_parent($apps_tnode);
    $mbr1_tnode->set_is_member(1);
    $mbr2_tnode->set_parent($apps_tnode);
    $mbr2_tnode->set_is_member(1);

    # fix the links to the a-layer
    my ($old_comma_tnode) = $first_comma_anode->get_referencing_nodes('a/aux.rf');
    $old_comma_tnode->remove_aux_anodes($first_comma_anode);
    $apps_tnode->set_lex_anode($first_comma_anode);
    
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::FixApps

=head1 DESCRIPTION

This block adds English appostion roots, if the parse tree allows it.
It must pass the following conditions:
* the two members of the apposition must be delimited by a comma
* both members of the apposition must be governed by a noun
* the second member cannot be governed by a proper noun
* the second member must be a child of a head of the first member

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

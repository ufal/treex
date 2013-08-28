package Treex::Block::HamleDT::Pdt2TreexIsMemberConversion;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $root ) = @_;
    foreach my $old_member (grep {$_->is_member} $root->get_descendants) {
        my $new_member = _climb_up_below_coap($old_member);
        if ($new_member && $new_member != $old_member) {
            $new_member->set_is_member(1);
            $old_member->set_is_member(undef);
        }
    }
}

sub _climb_up_below_coap {
    my ($node) = @_;
    if ($node->get_parent->is_root) {
        log_warn('No co/ap node between a co/ap member and the tree root');
        return;
    }
    elsif ($node->get_parent->is_coap_root) {
        return $node;
    }
    else {
        return _climb_up_below_coap($node->parent);
    }
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Pdt2TreexIsMemberConversion

=head1 DESCRIPTION

In the PDT style, the C<is_member> attribute is stored with the highest non-aux
node of a conjunct (for example, not with a preposition node, but with the noun, if
prepositional groups are coordinated). In the Treex style, C<is_member> is always
stored with direct children of co/ap nodes. This block converts the former style
to the latter style.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

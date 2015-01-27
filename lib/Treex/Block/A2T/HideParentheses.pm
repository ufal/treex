package Treex::Block::A2T::HideParentheses;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_left ) = @_;
    
    # Look for the left bracket
    return if $t_left->t_lemma ne '(';
    
    # Look for the right bracket among the siblings
    my $t_right = first {$_->t_lemma eq ')'} $t_left->get_siblings({following_only=>1});
    return if !$t_right;
    
    # Hide paired brackets
    my $t_parent = $t_left->get_parent();
    for my $t_bracket ($t_left, $t_right){
        my $a_bracket = $t_bracket->get_lex_anode();
        $t_parent->add_aux_anodes($a_bracket);
        $t_bracket->remove({children=>'rehang_warn'});
    }
    
    # Mark $t_parent as the root of the parenthesis 
    $t_parent->set_is_parenthesis(1);
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::HideParentheses - hide paired round brackets on t-layer and mark C<is_parenthesis>

=head1 DESCRIPTION

Fills C<is_parenthesis> attribute of parenthetized t-nodes,
i.e. nodes which on a-layer contain "(" and ")" among children.

This block expects that the parenthesis t-nodes are present on t-layer.
After applying this block, the parenthesis t-nodes are removed (i.e. hidden, i.e. encoded in the C<is_parenthesis> attribute).
Note that non-paired parentheses (e.g. a single parenthesis or a matching pair which does not share the same parent)
are not removed by this block.

This is an alternative to L<Treex::Core::Block::A2T::MarkParentheses>,
which expects the t-nodes corresponding to parentheses are already hidden (or never created)
and only sets the C<is_parenthesis> attribute based on the aux a-nodes.

=head2 Notice

This implementation is not compliant with PDT, where all nodes that should be included in the parenthesis
must have the C<is_parenthesis> attribute set, not only the parenthesis root (the reason is non-continuous
parentheses, see chapter 5.7 of the PDT T-layer annotation manual). This causes a lot of superfluous parentheses
when generating from PDT. However, it is not clear what to do with nested parentheses if the PDT-style marking 
would be used.   

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

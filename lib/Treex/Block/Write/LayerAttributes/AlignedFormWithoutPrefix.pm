package Treex::Block::Write::LayerAttributes::AlignedFormWithoutPrefix;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

sub modify_single {

    my ( $self, $anode ) = @_;
    my ( $aligned_nodes ) = $anode->get_directed_aligned_nodes();
    return '' if (!$aligned_nodes); # TODO return form of current node?
    
    my $aligned_node = shift @$aligned_nodes;
    return '' if (!$aligned_node);
    
    if ($anode->wild->{verbal_prefix}){
        my $form = $aligned_node->form;
        my $prefix = $anode->wild->{verbal_prefix};
        $form =~ s/^$prefix//i;
        return $form;
    }
    return $aligned_node->form;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::AlignedFormWithoutPrefix

=head1 DESCRIPTION

Prints the form of the aligned node; but if the current node is a verb with a separable
prefix, strips the prefix first.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

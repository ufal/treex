package Treex::Block::Write::AmrForTreeSurgeon;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::Amr';

with 'Treex::Block::Write::AttributeParameterized'; 

# Returns the t-node's lemma/label
sub _get_lemma {
    my ( $self, $tnode ) = @_;
    my $lemma = $tnode->t_lemma;
    my $info = $self->_get_info_hash($tnode);
    
    foreach my $attr_name (@{$self->_output_attrib}){
        my $val = $info->{$attr_name};
        $val =~ s/\s+/_/g;
        $attr_name =~ s/.*->//;
        $lemma .= ' ' . $attr_name . '=' . $val;
    }
    return $lemma;
}


1;

__END__

=head1 NAME

Treex::Block::Write::Amr

=head1 DESCRIPTION

Document writer for amr-like format.

=head1 ATTRIBUTES

=over

=item language

Language of tree


=item selector

Selector of tree

=back


=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

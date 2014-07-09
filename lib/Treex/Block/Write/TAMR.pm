package Treex::Block::Write::TAMR;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.amr' );

sub process_ttree {
    my ( $self, $ttree ) = @_;

    foreach my $ttop ($ttree->get_children({ordered=>1})){ 
        print { $self->_file_handle } '(' . $ttop->t_lemma;
        foreach my $child ($ttop->get_children({ordered=>1})){
            $self->_process_tnode($child, '    ');
        }
        print { $self->_file_handle } ")\n\n";
    }
}

sub _process_tnode {
    my ( $self, $tnode, $indent ) = @_;

    print { $self->_file_handle } "\n" . $indent . ':' . $tnode->functor . ' (' . $tnode->t_lemma;
    foreach my $child ($tnode->get_children({ordered=>1})){
        $self->_process_tnode($child, $indent . '    ');
    }
    print { $self->_file_handle } ")";
}

1;

__END__

=head1 NAME

Treex::Block::Write::TAMR

=head1 DESCRIPTION


=head1 ATTRIBUTES

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=back

=head1 AUTHOR


=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

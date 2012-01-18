package Treex::Block::Write::MosesTree;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

sub process_ptree {
    my ( $self, $ptree ) = @_;

    $self->print_ptree($ptree);
    print { $self->_file_handle } "\n";
}

sub print_ptree {
    my ( $self, $ptree ) = @_;
    my $label = $ptree->phrase;

    if (defined $label) {
        # a nonterminal
        print { $self->_file_handle } " <tree label=\"$label\">";
        foreach my $child ($ptree->children) {
            $self->print_ptree($child);
        }
        print { $self->_file_handle } " </tree>"
    } else {
        # a terminal
        my $tag = $ptree->tag;
        my $form = $ptree->form;
        print { $self->_file_handle } " <tree label=\"$tag\"> $form </tree>";
    }
}

1;

__END__

=head1 NAME

Treex::Block::Write::MosesTree

=head1 DESCRIPTION

Document writer for phrase-structure trees in moses_chart tree format.


=head1 ATTRIBUTES

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Ondrej Bojar

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

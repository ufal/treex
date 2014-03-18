package Treex::Block::Write::Stanford;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.stanford' );

has type_attribute => ( is => 'rw', isa => 'Str', default => 'conll/deprel' );

has retain_punct => ( is => 'ro', isa => 'Bool', default => 1 );

has version => ( is => 'ro', isa => 'Str', default => 'basic' );

has separator => ( is => 'ro', isa => 'Str', default => ', ' );

sub process_atree {
    my ( $self, $aroot ) = @_;

    my $separator = $self->separator;
    foreach my $anode ( $aroot->get_descendants( { ordered => 1 } ) ) {
        my $type = $anode->get_attr($self->type_attribute);
        if ( $type eq 'punct' && !$self->retain_punct ) {
            if ( $anode->get_children() ) {
                log_fatal "Error or node " . $anode->id . ": " .
                    "Punctuation must not have children when not retained!";
            }
            next;
        }
        my $governor  = $self->node_id($anode->get_parent());
        my $dependent = $self->node_id($anode);
        print { $self->_file_handle } "$type($governor$separator$dependent)\n";
    }
    print { $self->_file_handle } "\n";
    return;
}

sub node_id {
    my ($self, $anode) = @_;

    my $form = $anode->is_root() ? 'ROOT' : $anode->form;
    my $ord  = $anode->ord;

    return "$form-$ord";
}

1;

__END__

=head1 NAME

Treex::Block::Write::Stanford -- write the sentences in Stanford Dependencies
format.

=head1 DESCRIPTION

Document writer for Stanford Dependencies format
C<type(governor-ord, dependent-ord)>:

 nsubj(loves-2, John-1)
 root(ROOT-0, loves-2)
 dobj(loves-2, Mary-3)

=head1 ATTRIBUTES

=over

=item to

The name of the output file, STDOUT by default.

=item type_attribute

The a-node attribute containing the type of the dependency.
The default is C<conll/deprel> (since L<HamleDT::ToStanfordTypes> stores the
Stanford dependency types into C<conll/deprel>, not into C<afun>).

=item retain_punct

Defines whether to output punctuation (i.e. dependencies of type
C<punct>).
Punctuation is left out by default (C<0>).

Please note that this leads to the ord-tails of the words being discontinuos
if there is punctuation in the middle of the sentence (which is a feature of
the Stanford Dependencies).

=item version

Currently ignored, reserved for future use.

The version of Stanford Dependencies to use.
The default (and currently also the only allowed) value is C<basic>
(no collapsing of edges, no propagation of conjunct dependencies).

=item separator

The string to separate governor and dependent in the output. The default is
C<', '>, i.e. a comma and a space.

=back

=head1 AUTHOR

Rudolf Rosa

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

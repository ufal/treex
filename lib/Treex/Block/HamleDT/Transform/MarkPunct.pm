package Treex::Block::HamleDT::Transform::MarkPunct;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has attribute => ( is => 'rw', isa => 'Str', default => 'conll/deprel' );
has value => ( is => 'rw', isa => 'Str', default => 'punct' );

sub process_anode {
    my ( $self, $anode ) = @_;

    if ( $anode->match_iset( 'pos' => '~punc' ) || $anode->form =~ /^\p{IsP}+$/ ) {
        $anode->set_attr($self->attribute, $self->value);
    }

    return;
}

1;

=head1 NAME 

Treex::Block::HamleDT::Transform::MarkPunct -- mark punctuation nodes

=head1 DESCRIPTION

Detects a punctuation node as a node whose form consists only of punctuation
symbols (C<^\p{IsP}+$>) or whose interset part of speech is C<punc>.

Sets the C<attribute> of each such node to C<value>.

=head1 PARAMETERS

=over

=item attribute

The attribute to be set. C<conll/deprel> by default.

=item value

The value to be used for the C<attribute>. C<punct> by default (used e.g. in
Stanford Dependencies).

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


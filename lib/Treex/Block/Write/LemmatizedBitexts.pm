package Treex::Block::Write::LemmatizedBitexts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has encoding => (
    is            => 'ro',
    default       => 'utf8',
    documentation => 'Output encoding. By default utf8.',
);

has to_language => ( is => 'ro', isa => 'Str', required => 1 );
has to_selector => ( is => 'ro', isa => 'Str', default  => '' );

sub BUILD {
    my ($self) = @_;
    binmode STDOUT, ':encoding(' . $self->encoding . ')';
    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;
    my $bundle = $a_root->get_bundle;
    print $bundle->get_document->loaded_from . "-" . $bundle->id . "\t";
    print join( " ", map { $_->lemma } $a_root->get_descendants( { ordered => 1 } ) ) . "\t";
    print join( " ", map { $_->lemma } $bundle->get_tree( $self->to_language, 'a', $self->to_selector )->get_descendants( { ordered => 1 } ) ) . "\n";
    return;
}

1;

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

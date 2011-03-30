package Treex::Block::T2A::CS::FillTagFromMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my @CATEGORIES = qw(pos subpos gender number case possgender possnumber
    person tense grade negation voice);

sub process_anode {
    my ( $self, $anode ) = @_;
    return if defined $anode->tag;
    my $tag = '';
    for my $cat (@CATEGORIES) {
        $tag .= $self->guess_one_symbol( $anode->get_attr("morphcat/$cat") );
    }
    $anode->set_tag($tag);
    return;
}

sub guess_one_symbol {
    my ( $self, $spec ) = @_;
    return '-' if !defined $spec;
    return $spec if $spec =~ /^.$/;
    return $1    if $spec =~ /^\[(.)/;
    return '-';
}

1;

__END__

=over

=item Treex::Block::T2A::CS::FillTagFromMorphcat

Fill Czech positional morphological tag by concatenating individual positions.
This is just an approximation, because the individual positions
stored in attributes C<morphcat/*> can contain regex underspecification.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

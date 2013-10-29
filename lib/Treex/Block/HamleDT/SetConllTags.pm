package Treex::Block::HamleDT::SetConllTags;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

use tagset::google;

has features => (
    is => 'rw',
    isa => 'Str',
    default => 'subpos',
);

has _features => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    builder => '_build_features',
    writer => '_set_features',
);

sub _build_features {
    my ( $self ) = @_;
    my @f = split /,/, $self->features;
    $self->_set_features( \@f );
}

sub process_anode {
    my ($self, $anode) = @_;

    my $cpos = tagset::google::encode($anode->get_iset_structure);
    $anode->set_conll_cpos($cpos);
    
    my $pos = $cpos;
    foreach my $feature (@{$self->_features}) {
        my $value = $anode->get_iset($feature);
        if ( $value ne '' ) {
            $pos .= "_$value";
        }
    }
    $anode->set_conll_pos($pos);

    return;
}

1;

=head1 NAME 

Treex::Block::HamleDT::SetConllTags

=head1 DESCRIPTION

Uses Interset to set CoNLL POS tags.

Sets C<conll/cpos> to Google universal POS tag
and C<conll/pos> to C<conll/cpos>, joined by underscores with values of C<features>
(only subpos by default) if they are not empty.

=head1 PARAMETERS

=over

=item features
The Interset features to form the tail of the tag -- a comma-separated list
(e.g. C<subpos,prontype,numtype>).

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


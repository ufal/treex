package Treex::Block::A2A::DE::CoNLL2Iset;

use Moose;
use Treex::Core::Common;
use Lingua::Interset qw(decode encode);

extends 'Treex::Core::Block';

has 'overwrite' => ( isa => 'Bool', is => 'ro', default => 0 );

sub process_anode {

    my ( $self, $anode ) = @_;
    return if ( !defined( $anode->tag ) );

    my $tag = $anode->tag;
    my $feat = defined $anode->conll_feat ? $anode->conll_feat : "_";

    # Just in case
    $feat = join "\|", (map {ucfirst($_)} split /\|/, $feat);

    my $combined_tag = "$tag $feat";

    my $f = decode( "de::conll2009", $combined_tag );
    $anode->set_iset($f);
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::DE::CoNLL2Iset

=head1 DESCRIPTION

Create interset structure from the CoNLL2009 style annotated data.

TODO:

=head1 PARAMETERS

=over

=item C<overwrite>

Indicates that the original tag should be overwritten by the converted tag.

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.ms.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

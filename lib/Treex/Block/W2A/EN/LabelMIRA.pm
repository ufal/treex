package Treex::Block::W2A::EN::LabelMIRA;
use Moose;
extends 'Treex::Block::W2A::LabelMIRA';

has 'model_name' => ( is => 'ro', isa => 'Str', default => 'alg16_5_p1' );
has 'model_dir' => ( is => 'ro', isa => 'Str', default => "data/models/parser/mst_perl/en" );

has 'alignment_language' => ( isa => 'Str', is => 'ro', default => 'cs' );
has 'alignment_is_backwards' => ( isa => 'Bool', is => 'ro', default => '0' );

sub get_coarse_grained_tag {
    my ( $self, $tag ) = @_;

    my $ctag = substr( $tag, 0, 2 );

    return $ctag;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::EN::LabelMIRA

=head1 DECRIPTION

Mira labeller adjusted to labelling English sentences.
Just a lightweight wrapper for
L<Treex::Block::W2A::LabelMIRA> which is the labeller itself.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

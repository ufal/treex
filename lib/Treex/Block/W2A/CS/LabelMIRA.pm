package Treex::Block::W2A::CS::LabelMIRA;
use Moose;
extends 'Treex::Block::W2A::LabelMIRA';

has 'model_name' => ( is => 'ro', isa => 'Str', default => 'alg16_5_p1' );
has 'model_dir' => ( is => 'ro', isa => 'Str', default => "data/models/labeller_mira/cs" );

has 'alignment_language' => ( isa => 'Str', is => 'ro', default => 'en' );
has 'alignment_is_backwards' => ( isa => 'Bool', is => 'ro', default => '1' );

sub get_coarse_grained_tag {
    my ( $self, $tag ) = @_;
    
    my $ctag;
    if ( substr( $tag, 4, 1 ) eq '-' ) {
	# no case -> Pos + Subpos
        $ctag = substr( $tag, 0, 2 );
    } else {
	# has case -> Pos + Case
        $ctag = substr( $tag, 0, 1 ) . substr( $tag, 4, 1 );
    }

    return $ctag;
}

1;

__END__
 
=head1 NAME

Treex::Block::W2A::CS::LabelMIRA

=head1 DECRIPTION

Mira labeller adjusted to labelling Czech sentences.
Just a lightweight wrapper for
L<Treex::Block::W2A::LabelMIRA> which is the labeller itself.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

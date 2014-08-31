package Treex::Block::W2A::CS::ParseMSTperl;

use strict;
use warnings;
use Moose;
extends 'Treex::Block::W2A::ParseMSTperl';

has 'model_name' => ( is => 'ro', isa => 'Str', default => 'pdt_form_small' ); #pdt_dz_wf_3 was here, but I cannot find such a model in share
has 'model_dir' => ( is => 'ro', isa => 'Str', default => "data/models/parser/mst_perl/cs" );

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

Treex::Block::W2A::CS::ParseMSTperl

=head1 DECRIPTION

MST parser adjusted to parsing Czech sentences.
Just a lightweight wrapper for
L<Treex::Block::W2A::ParseMSTperl> which is the parser itself.

Uses a rather small and simple model, which is good only for testing and toy
examples.
Use e.g. C<model_name=pdt_best> to get good results.

=head1 COPYRIGHT

Copyright 2011 Rudolf Rosa
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

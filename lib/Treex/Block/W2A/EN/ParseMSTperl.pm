package Treex::Block::W2A::EN::ParseMSTperl;
use Moose;
extends 'Treex::Block::W2A::ParseMSTperl';

has 'model_name' => ( is => 'ro', isa => 'Str', default => 'conll_2007' );
has 'model_dir' => ( is => 'ro', isa => 'Str', default => "data/models/mst_perl_parser/en" );

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

Treex::Block::W2A::EN::ParseMSTperl

=head1 DECRIPTION

MST parser adjusted to parsing English sentences.
Just a lightweight wrapper for
L<Treex::Block::W2A::ParseMSTperl> which is the parser itself.

=head1 COPYRIGHT

Copyright 2011 Rudolf Rosa
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

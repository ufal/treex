package Treex::Block::W2A::EN::ParseMSTperl;

use strict;
use warnings;
use Moose;
extends 'Treex::Block::W2A::ParseMSTperl';

has '+model_name' => ( default => 'conll_2007_small' );
has '+model_dir' => ( default => 'data/models/parser/mst_perl/en' );

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
L<Treex::Block::W2A::ParseMSTperl> which is base clase.
This class just sets the English model C<conll_2007_small> as the default
and defines a method for obtaining coarse-grained PoS tags
(first two characters of PennTB-like tags).

The default model is very small and good only for testing and demonstration
purposes.
Use e.g. C<model_name=conll_2007_best> instead to get good results.

=head1 SEE ALSO

L<Treex::Block::W2A::ParseMSTperl>

L<Treex::Tool::Parser::MSTperl::Parser>

=head1 COPYRIGHT

Copyright 2011 Rudolf Rosa
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

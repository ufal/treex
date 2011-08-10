package Treex::Block::Write::Senseval2;

use Moose;
use Treex::Core::Common;
use autodie;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';
with 'Treex::Block::Write::LayerAttributes';

has '+language' => ( required => 1 );

has 'separator' => ( isa => 'Str', is => 'ro', default => ' ' );

has 'connector' => ( isa => 'Str', is => 'ro', default => '^' );

has '_sent_ctr' => ( isa => 'Int', is => 'rw', default => 1 );

sub _process_tree() {

    my ( $self, $tree ) = @_;

    my @nodes = $tree->get_descendants( { ordered => 1 } );

    print { $self->_file_handle } '<intance id="' . $self->_sent_ctr . '">\n<answer instance="' . $self->_sent_ctr
        . '" senseid="NOTAG" />' . "\n<context>\n";

    my $sent_data = join $self->separator, map { join $self->connector, @{ $self->_get_info_list($_) } } @nodes;

    # compulsory XML entities
    $sent_data =~ s/&/&amp;/g;
    $sent_data =~ s/</\&lt;/g;
    $sent_data =~ s/>/\&gt;/g;
    $sent_data =~ s/"/\&quot;/g;
    $sent_data =~ s/'/\&apos;/g;

    print { $self->_file_handle } $sent_data;

    print { $self->_file_handle } "\n</context>\n</instance>\n";
    $self->_set_sent_ctr( $self->_sent_ctr + 1 );
}

sub BUILD {
    my ($self) = @_;
    print { $self->_file_handle } '<corpus lang="' . $self->language . "\">\n<lexelt item=\"LEXELT\">\n";
}

sub DEMOLISH {
    my ($self) = @_;
    print { $self->_file_handle } "</lexelt>\n</corpus>\n";
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::Senseval2

=head1 DESCRIPTION

Given a list of attributes to print out, this saves their values in a L<Senseval-2|http://www.senseval.org/> format. Values
of multiple attributes per one word are connected with the C<connector> character, the words on a line are separated with
the C<separator> character.   

=head1 ATTRIBUTES

=over

=item C<language>

The selected language. This parameter is required.

=item C<attributes>

A space-separated list of attributes whose values should be printed for the individual nodes. This parameter is required.

For multiple-valued attributes (lists) and dereferencing attributes, please see L<Treex::Block::Write::LayerAttributes>. 

=item C<layer>

The annotation layer where the desired attributes are found (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<separator>

The separator character for the individual values within one sentence. Space is the default.

=item C<connector>

The connector character for the values of different attributes of the same word. The circumflex ('^') character is the default.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

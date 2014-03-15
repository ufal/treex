package Treex::Block::Write::AttributeSentences;

use Moose;
use Treex::Core::Common;
use autodie;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Write::LayerParameterized';
with 'Treex::Block::Write::AttributeParameterized';

has '+language' => ( required => 1 );

has 'separator' => ( isa => 'Str', is => 'ro', default => ' ' );

has 'attr_sep' => ( isa => 'Str', is => 'ro', default => '|' );

has 'sent_sep' => ( isa => 'Str', is => 'ro', default => "\n", documentation => 'What to print after each sentence' );

has '+extension' => ( default => '.txt' );

has '+instead_undef' => ( default => "" );

has instead_empty_tree => ( is => 'ro', isa => 'Str', default => '', documentation => 'What line to write instead of empty tree. Default is the empty string.' );

has skip_nodes => (
    isa => 'Str',
    is => 'ro',
    default => '',
    documentation => 'Perl expression specifying which nodes should be skipped (not printed)',
);

# Change '\n', '\r', '\t'
sub BUILDARGS {
    my ( $self, $args ) = @_;

    if ( defined $args->{separator} && $args->{separator} =~ /^((\\[nrt])+)$/ ) {
        $args->{separator} = eval "return \"$1\"";
    }
    if ( defined $args->{attr_sep} && $args->{attr_sep} =~ /^((\\[nrt])+)$/ ) {
        $args->{attr_sep} = eval "return \"$1\"";
    }
    if ( defined $args->{sent_sep} && $args->{sent_sep} =~ /^((\\[nrt])+)$/ ) {
        $args->{sent_sep} = eval "return \"$1\"";
    }
    return $args;
}

has [qw(_node_regex _attr_regex _node_esc _attr_esc)] => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    my $node_sep = substr( $self->separator, 0, 1 );
    my $node_esc = '&#' . ord($node_sep) . ';';
    $self->_set_node_regex(qr/\Q$node_sep\E/);
    $self->_set_node_esc( '&#' . ord($node_sep) . ';' );
    my $attr_sep = substr( $self->attr_sep, 0, 1 );
    my $attr_esc = '&#' . ord($attr_sep) . ';';
    $self->_set_attr_regex(qr/\Q$attr_sep\E/);
    $self->_set_attr_esc( '&#' . ord($attr_sep) . ';' );
    return;
}

sub _process_tree() {
    my ( $self, $tree ) = @_;

    my @nodes = $tree->get_descendants( { ordered => 1 } );
    if ($self->skip_nodes) {
        @nodes = grep {! eval($self->skip_nodes)} @nodes;
    }
    if (!@nodes) {
      print { $self->_file_handle } $self->instead_empty_tree;
    } else {
        print { $self->_file_handle }
            join $self->separator,
            map {
                join $self->attr_sep, map { $self->escape($_) } @{ $self->_get_info_list($_) }
            } @nodes;
    }

    print { $self->_file_handle } $self->sent_sep;
}

sub escape {
    my ( $self, $string ) = @_;
    my ( $aa, $bb ) = ( $self->_attr_regex, $self->_attr_esc );
    $string =~ s/$aa/$bb/g;
    ( $aa, $bb ) = ( $self->_node_regex, $self->_node_esc );
    $string =~ s/$aa/$bb/g;
    return $string;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::AttributeSentences

=head1 SYNOPSIS

  # print "Moses factored" formar: one sentence per line, each a-node as form|lemma|tag
  treex Write::AttributeSentences layer=a attributes=form,lemma,tag -- data.treex.gz

  # print form, lemma, tag and parent lemma; tab-separated values, one word per line
  treex Read::Treex from=data.treex.gz Write::AttributeSentences to=- \
    language=cs layer=a attributes='form lemma tag parent->lemma' separator='\n' attr_sep='\t' 

  # print wild attributes of words with lemma ending with "man"
  treex layer=a attributes=wild_MyAttribute skip_nodes='$_->lemma !~ /man$/' -- data.treex.gz
  
=head1 DESCRIPTION

This prints the values of the selected attributes for all nodes in a tree, one sentence per line. 

For multiple-valued attributes (lists) and dereferencing attributes, please see 
L<Treex::Block::Write::AttributeParameterized>.

Default separator of tokens (see L<separator>) is space.
Default separator of attributes (see L<attr_sep>) is vertical bar ("|").
If the attributes to be printed contain any of those separator symbols,
they will be escaped like HTML entities, i.e. space will be converted to I<&#32;> and bar to I<&#124;>.
However, it is recommended to selecet such separator symbols that do not appear in your data.

=head1 ATTRIBUTES

=over

=item C<language>

The selected language. This parameter is required.

=item C<attributes>

The name of the attributes whose values should be printed for the individual nodes. This parameter is required.

=item C<layer>

The annotation layer where the desired attribute is found (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<separator>

The separator character for the individual nodes within one sentence. Space is the default. C<\n>, C<\t> and C<\r> 
provided as values will be replaced by LF, tab and CR, respectively.

=item C<attr_sep>

The separator character for the individual attribute values for one node. Vertical bar ("|") is the default.
C<\n>, C<\t> and C<\r> provided as values will be replaced by LF, tab and CR, respectively.

=item C<sent_sep>

The separator character for sentences (printed also after the last sentence). Newline ("\n") is the default.
C<\n>, C<\t> and C<\r> provided as values will be replaced by LF, tab and CR, respectively.


=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

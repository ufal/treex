package Treex::Block::Read::YAML;

use Moose;
use Treex::Core::Common;
use YAML::Any;
use Data::Dumper;
use File::Slurp;

extends 'Treex::Block::Read::BaseReader';
with 'Treex::Block::Read::BaseSplitterRole';

sub next_document_text {

    my ($self) = @_;
    my $filename = $self->next_filename or return;
    my $text;

    if ( $filename eq '-' ) {
        $text = read_file( \*STDIN );
    }

    # TODO: support encodings other than UTF-8?
    # reading from a gzipped file
    elsif ( $filename =~ /.gz$/ ) {
        open my $fh, "gunzip -c $filename |";
        $text = read_file( $fh, binmode => 'encoding(utf8)', err_mode => 'log_fatal' );
        utf8::decode($text);    # this is weird, but must be done
        close $fh;
    }
    else {
        $text = read_file( $filename, binmode => 'encoding(utf8)', err_mode => 'log_fatal' );
    }
    return $text;
}

sub next_document {
    my ($self) = @_;

    my $text = $self->next_document_text();
    return if !defined $text;

    utf8::encode($text);    # encoding hack (so that the file is human-readable)
    my $yaml_bundles = Load($text);

    my $document = $self->new_document();
    foreach my $yaml_bundle ( @{$yaml_bundles} ) {

        my $bundle = $document->create_bundle();

        foreach my $yaml_zone ( @{$yaml_bundle} ) {

            my $zone = $bundle->create_zone( $yaml_zone->{language}, $yaml_zone->{selector} );

            $zone->set_sentence( $yaml_zone->{sentence} ) if ( defined( $yaml_zone->{sentence} ) );

            foreach my $layer (qw(a t n p)) {
                if ( defined( $yaml_zone->{ $layer . 'tree' } ) ) {
                    my $root = $zone->create_tree($layer);
                    $self->deserialize_tree( $root, $layer, $yaml_zone->{ $layer . 'tree' } );
                }
            }
        }
    }
    return $document;
}

# Deserialize a node and, recursively, its children
sub deserialize_tree {
    my ( $self, $root, $layer, $yaml_data ) = @_;

    foreach my $attr ( keys %{$yaml_data} ) {

        # deserialize all nodes
        if ( $attr eq 'nodes' ) {

            # hang them all under root for now
            foreach my $yaml_node ( @{ $yaml_data->{nodes} } ) {
                my $node;
                if ( $layer eq 'p' ) {
                    if ( defined( $yaml_node->{phrase} ) ) {
                        $node = $root->create_nonterminal_child();
                    }
                    else {
                        $node = $root->create_terminal_child();
                    }
                }
                else {
                    $node = $root->create_child();
                }
                $self->deserialize_node( $node, $layer, $yaml_node );
            }
            next;
        }

        # this works even for IDs and Treex::PML arrays, which makes it simpler
        $root->set_attr( $attr, $yaml_data->{$attr} );
    }

    # now find the right parents for the roots
    my $doc = $root->get_document();
    foreach my $node ( $root->get_descendants() ) {
        $node->set_parent( $doc->get_node_by_id( $node->get_attr('parent_id') ) );
    }
    return;
}

sub deserialize_node {
    my ( $self, $node, $layer, $yaml_data ) = @_;

    foreach my $attr ( keys %{$yaml_data} ) {

        # assign the 'parent_id' attribute as well
        # this works even for IDs and Treex::PML arrays, which makes it simpler
        $node->set_attr( $attr, $yaml_data->{$attr} );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Read::YAML

=head1 DESCRIPTION

Read a YAML file containing Treex structures (as arrays and hashes), such as a YAML file 
written by L<Treex::Block::Write::YAML>. 

The YAML file must contain an array of bundles, each being an array of zones. A zone is a hash,
containing the following values: C<language>, C<selector>, C<sentence> and C<Xtree>, where C<X> 
can be C<a>, C<t>, C<n> or C<p>. The tree entries then contain the entire tree structure with 
usual attributes for nodes on the individual layers; the topological children of a node are
contained in the attribute C<children> (which is an array of nodes).
   
=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

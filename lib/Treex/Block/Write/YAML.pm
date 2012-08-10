package Treex::Block::Write::YAML;

use Moose;
use Treex::Core::Common;
use YAML::Any;

extends 'Treex::Block::Write::BaseTextWriter';

# Default process_document method for all Writer blocks.
override 'process_document' => sub {

    my ( $self, $document ) = @_;

    # set _file_handle properly (this MUST be called if process_document is overridden)
    $self->_prepare_file_handle($document);

    my @bundles;
    foreach my $bundle ( $document->get_bundles() ) {
        push @bundles, $self->serialize_bundle($bundle);
    }
    my $yaml_text = Dump(\@bundles);

    # hacks with the produced YAML here (avoid double UTF8 for human readability,
    # convert Treex::PML::whatever arrays/hashes to plain ones)
    utf8::decode($yaml_text);
    $yaml_text =~ s{!!perl/(hash|array):\S+}{}g;

    print { $self->_file_handle } $yaml_text;
    return;
};

sub serialize_bundle {
    my ( $self, $bundle ) = @_;
    my @zones;
    foreach my $zone ( $bundle->get_all_zones() ) {
        push @zones, $self->serialize_zone($zone);
    }
    return \@zones;
}

sub serialize_zone {
    my ( $self, $zone ) = @_;
    my %data;

    $data{selector} = $zone->selector;
    $data{language} = $zone->language;
    $data{sentence} = $zone->sentence;

    foreach my $tree ( $zone->get_all_trees() ) {
        $data{ $tree->get_layer() . 'tree' } = $self->serialize_node( $tree->get_layer(), $tree );
    }
    return \%data;
}

# Attributes of the individual trees to be saved
# TODO: a_tree.rf, val_frame.rf in t-trees (needed at all?)
Readonly my $ATTR => {
    t => [
        qw(id ord t_lemma functor formeme nodetype subfunctor tfa
            is_dsp_root gram a compl.rf coref_gram.rf coref_text.rf
            sentmod is_parenthesis is_passive is_generated
            is_relclause_head is_name_of_person voice
            t_lemma_origin formeme_origin is_infin is_member)
    ],
    a => [
        qw(id ord form lemma tag afun no_space_after
            s_parenthesis_root edge_to_collapse is_auxiliary
            p_terminal.rf is_member)
    ],
    n => [qw(id ne_type normalized_name a.rf)],
    p => [
        qw(id is_head index coindex edgelabel form lemma
            tag phrase functions)
    ],
};

sub serialize_node {
    my ( $self, $layer, $node ) = @_;
    my %data;

    # save all attributes with defined values
    foreach my $attr ( @{ $ATTR->{$layer} } ) {
        my $value = $node->get_attr($attr);
        $data{$attr} = $value if ( defined($value) );
    }

    # recurse to children
    $data{children} = [ map { $self->serialize_node( $layer, $_ ) } $node->get_children( { ordered => 1 } ) ];
    return \%data;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::YAML

=head1 DESCRIPTION

Write the whole Treex document as a simple YAML file (composed entirely of arrays and hashes).

The YAML file will contain an array of bundles, each being an array of zones. A zone is a hash,
containing the following values: C<language>, C<selector>, C<sentence> and C<Xtree>, where C<X> 
can be C<a>, C<t>, C<n> or C<p>. The tree entries then contain the entire tree structure with 
usual attributes for nodes on the individual layers; the topological children of a node are
contained in the attribute C<children> (which is an array of nodes).

Any attributes whose value was not defined are not mentioned in the output YAML. 
   
=item C<to>

Optional: the name of the output file, STDOUT by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

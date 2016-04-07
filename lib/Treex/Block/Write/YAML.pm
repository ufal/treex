package Treex::Block::Write::YAML;

use Moose;
use Treex::Core::Common;
use YAML::Any;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.yaml' );

# Default process_document method for all Writer blocks.
override '_do_process_document' => sub {

    my ( $self, $document ) = @_;

    # get the YAML dump of everything

    my @bundles;
    foreach my $bundle ( $document->get_bundles() ) {
        push @bundles, $self->serialize_bundle($bundle);
    }
    my $yaml_text = Dump( \@bundles );

    # now do some hacks so that the produced YAML can be loaded elsewhere (i.e., by PyYAML)

    # avoid double UTF8 for human readability
    utf8::decode($yaml_text);

    # convert Treex::PML::whatever arrays/hashes to plain ones)
    $yaml_text =~ s{!!perl/(hash|array):\S+}{}g;
    $yaml_text =~ s{(^[^:]+:\s*)([0-9]+_[0-9_]+)(\s*(?:,|$))}{$1'$2'$3}mg;    # enquote numbers with underscores
    $yaml_text =~ s{: =$}{: '='}mg;                                           # enquote equal signs or PyYAML won't read them
    $yaml_text =~ s{: ''$}{: ""}mg;                                           # always put empty strings in double quotes
                                                                              # enquote words that would be considered boolean by PyYAML,
                                                                              # but avoid enquoting their usage inside sentences (where they aren't considered boolean)
    $yaml_text =~ s{(^(?![ -]*sentence)[^:]+:\s*)(on|off|yes|no)(\s*(?:,|$))}{$1'$2'$3}mg;
    $yaml_text =~ s{(^[^:]+:\s*)(on|off|yes|no)(\s*$)}{$1'$2'$3}mg;

    # output the result

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
        $data{ $tree->get_layer() . 'tree' } = $self->serialize_tree( $tree->get_layer(), $tree );
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
            t_lemma_origin formeme_origin is_infin is_member
            clause_number is_clause_head is_reflexive mlayer_pos
            src_tnode.rf wild)
    ],
    a => [
        qw(id ord form lemma tag afun no_space_after
            s_parenthesis_root edge_to_collapse is_auxiliary
            p_terminal.rf is_member clause_number is_clause_head
            iset wild)
    ],
    n => [qw(id ne_type normalized_name a.rf wild)],
    p => [
        qw(id is_head index coindex edgelabel form lemma
            tag phrase functions wild)
    ],
};

sub serialize_tree {
    my ( $self, $layer, $root ) = @_;
    my %data;

    # ordered for A, T nodes, otherwise unordered
    my $args = $layer =~ /[at]/ ? { ordered => 1 } : {};

    # root attributes
    foreach my $attr ( @{ $ATTR->{$layer} } ) {
        my $value = $root->get_attr($attr);
        $data{$attr} = $value if ( defined($value) );
    }

    # all descendants
    $data{nodes} = [
        map { $self->serialize_node( $layer, $_ ) }
            $root->get_descendants($args)
    ];

    return \%data;
}

sub serialize_node {
    my ( $self, $layer, $node ) = @_;
    my %data;

    # save all attributes with defined values
    foreach my $attr ( @{ $ATTR->{$layer} } ) {
        my $value = $node->get_attr($attr);

        if ( $attr eq 'iset' ) {    # exclude empty Interset values
            foreach my $key ( keys %$value ) {
                delete $value->{$key} if ( $value->{$key} eq '' );
            }
        }
        if ( $attr eq 'gram' ) {    # do not write empty grammateme values
            foreach my $key ( keys %$value ) {
                delete $value->{$key} if ( !defined( $value->{$key} ) );
            }
        }

        $data{$attr} = $value if ( defined($value) );
    }
    $data{parent_id} = $node->get_parent()->id;
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

=over

=item C<to>

Optional: the name of the output file, STDOUT by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

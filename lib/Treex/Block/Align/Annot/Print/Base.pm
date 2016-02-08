package Treex::Block::Align::Annot::Print::Base;

use Moose;
use Moose::Util 'apply_all_roles';
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';
# Applied at runtime:
# with 'Treex::Block::Filter::Node' => { layer => $self->layer };

has 'aligns' => ( is => 'ro', isa => 'Str', required => 1 );
has '_aligns_graph' => ( is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1 );

sub BUILD {
    my ($self) = @_;
    $self->_aligns_graph;
}

sub _build_aligns_graph {
    my ($self) = @_;
    my @align_pairs = split /;/, $self->aligns;
    my $aligns_graph = {};
    foreach my $align_pair (@align_pairs) {
        my ($langs, $type) = split /:/, $align_pair, 2;
        my ($l1, $l2) = split /-/, $langs, 2;
        $aligns_graph->{$l1}{$l2} = $type;
        $aligns_graph->{$l2}{$l1} = $type;
    }
    return $aligns_graph;
}

# returns a HashRef with all languages as its keys and lists of aligned nodes as the values
# the method requires that alignment links form a path over all languages => each language
# is aligned with at most two other languages - these alignemnts must be specified in the
# <$aligns> parameter
sub _aligned_nodes {
    my ($self, $node) = @_;
    my $aligned_nodes = {
        $self->language => [ $node ],
    };
    my %aligns_graph = %{$self->_aligns_graph};
    my @lang_queue = ( $self->language );
    while (my $l1 = shift @lang_queue) {
        print STDERR "Processing Lang $l1\n";
        my $aligned_to_lang = $aligns_graph{$l1} // {};
        foreach my $l2 (keys %$aligned_to_lang) {
            my @rel_types = split /,/, $aligned_to_lang->{$l2};
            print STDERR Dumper(\@rel_types);
            my @all_ali_nodes = map { 
                print STDERR "Searching counterparts for ". $_->id . ": language=" . $l2 . ", selector=" . $_->selector . ", reltypes=" . join ",", @rel_types . "\n";
                my ($ali_nodes, $ali_types) = $_->get_undirected_aligned_nodes({
                    language => $l2, 
                    selector => $_->selector, 
                    rel_types => \@rel_types
                });
                @$ali_nodes
            } @{$aligned_nodes->{$l1}};
            $aligned_nodes->{$l2} = \@all_ali_nodes;
            print STDERR "$l1 -> $l2 : " . join ", ", map {$_->id} @all_ali_nodes;
            print STDERR "\n";
            push @lang_queue, $l2;
            delete $aligns_graph{$l1}{$l2};
            delete $aligns_graph{$l2}{$l1};
        }
    }
}

sub _process_node {
    my ($self, $node) = @_;

    my $nodes = $self->_aligned_nodes($node);
    my @langs = ($self->language, sort grep {$_ ne $self->language} keys %$nodes);
    my @zones = map {$node->get_bundle->get_zone($_, $self->selector)} @langs;

    print {$self->_file_handle} "ID: " . $node->get_address . "\n";

    $self->print_sentences($nodes, \@langs, \@zones);

    for (my $i = 1; $i < @langs; $i++) {
        print {$self->_file_handle} "INFO_".uc($langs[$i]).":\t\n";
    }
    print {$self->_file_handle} "\n";
}

1;

__END__

=head1 NAME

Treex::Block::Align::Annot::Print;

=head1 DESCRIPTION


=head1 PARAMETERS

=over

=item node_types

A comma-separated list of the node types on which this block should be applied.
See C<Treex::Tool::Coreference::NodeFilter> for possible values.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::Align::Annot::Print::Base;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/all any/;
use Moose::Util::TypeConstraints;

extends 'Treex::Block::Write::BaseTextWriter';

subtype 'LangsArrayRef' => as 'ArrayRef';
coerce 'LangsArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'align_langs' => ( is => 'ro', isa => 'LangsArrayRef', coerce => 1, required => 1 );
has 'gold_ali_type' => ( is => 'ro', isa => 'Str', default => 'gold' );
#
#has 'aligns' => ( is => 'ro', isa => 'Str', required => 1 );
#has '_aligns_graph' => ( is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1 );
#
#sub BUILD {
#    my ($self) = @_;
#    $self->_aligns_graph;
#}
#
#sub _build_aligns_graph {
#    my ($self) = @_;
#    my @align_pairs = split /;/, $self->aligns;
#    my $aligns_graph = {};
#    foreach my $align_pair (@align_pairs) {
#        my ($langs, $type) = split /:/, $align_pair, 2;
#        my ($l1, $l2) = split /-/, $langs, 2;
#        $aligns_graph->{$l1}{$l2} = $type;
#        $aligns_graph->{$l2}{$l1} = $type;
#    }
#    return $aligns_graph;
#}

sub get_gold_aligns {
    my ($self, $node) = @_;
    my %gold_aligns = map {
        my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes({ 
            language => $_, 
            selector => $node->selector, 
            rel_types => [$self->gold_ali_type],
        });
        $_ => $ali_nodes;
    } @{$self->align_langs};
    $gold_aligns{$node->language} = [$node];
    return \%gold_aligns;
}

sub already_annotated_langs {
    my ($gold_aligns) = @_;

    my @all_langs = keys %$gold_aligns;
    my %annotated_langs = ();
    foreach my $lang (@all_langs) {
        my $lang_nodes = $gold_aligns->{$lang};
        my @align_infos = grep {defined $_} map {$_->wild->{align_info}} @$lang_nodes;
        foreach my $align_info (@align_infos) {
            $annotated_langs{$_} = 1 foreach (keys %$align_info);
        }
    }
    return \%annotated_langs;
}

sub get_giza_aligns {
    my ($self, $node, $gold_aligns) = @_;

    my $start_list = [ $node ];
    my $giza_aligns = { $node->language => $start_list };
    my @queue = ( $start_list );
    my @other_langs = grep {!defined $giza_aligns->{$_}} sort keys %$gold_aligns;

    while (@other_langs && @queue) {
        my $curr_list = shift @queue;
        foreach my $lang (@other_langs) {
            my @lang_list = map {
                my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes({ 
                    language => $lang, 
                    selector => $node->selector,
                    # every type except for the 'gold'
                    rel_types => ["!".$self->gold_ali_type, ".*"],
                });
                @$ali_nodes;
            } @$curr_list;
            $giza_aligns->{$lang} = \@lang_list;
            push @queue, \@lang_list if (@lang_list);
        }
        @other_langs = grep {!defined $giza_aligns->{$_}} sort keys %$gold_aligns;
    }
    return $giza_aligns;
}

sub _process_node {
    my ($self, $node) = @_;

    my $gold_aligns = $self->get_gold_aligns($node);
    
    # extract all align_infos and find out how many languages are covered
    # it should be one language fewer than the number of all languages
    my @all_langs = keys %$gold_aligns;
    my $annotated_langs = already_annotated_langs($gold_aligns);
    return if (scalar @all_langs == (scalar keys %$annotated_langs) + 1);
    
    my $giza_aligns = $self->get_giza_aligns($node, $gold_aligns);
    my %merged_aligns = map {$_ => ( $annotated_langs->{$_} ? $gold_aligns->{$_} : ($giza_aligns->{$_} // []))} keys %$gold_aligns;

    my @langs = ($self->language, sort grep {$_ ne $self->language} keys %merged_aligns);
    my @zones = map {$node->get_bundle->get_zone($_, $self->selector)} @langs;

    print {$self->_file_handle} "ID: " . $node->get_address . "\n";

    $self->print_sentences(\%merged_aligns, \@langs, \@zones);

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

package Treex::Block::Align::T::Compare;

use Moose;
use Treex::Core::Common;

use Term::ANSIColor;

use Treex::Tool::Align::Utils;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Filter::Node::T';

has '+node_types' => ( default => 'all_anaph' );
has 'align_language' => (is => 'ro', isa => 'Str', required => 1);
has 'true_align_type' => (is => 'ro', isa => 'Str', default => 'gold');
has 'pred_align_type' => (is => 'ro', isa => 'Str', default => '!gold,!robust,!supervised,.*');

has '_true_align_filter' => (is => 'ro', isa => 'HashRef', builder => '_build_taf', lazy => 1);
has '_pred_align_filter' => (is => 'ro', isa => 'HashRef', builder => '_build_paf', lazy => 1);

sub _build_taf {
    my ($self) = @_;
    my @tat = split /,/, $self->true_align_type;
    return { language => $self->align_language, rel_types => \@tat };
}
sub _build_paf {
    my ($self) = @_;
    my @tat = split /,/, $self->pred_align_type;
    return { language => $self->align_language, rel_types => \@tat };
}

sub _linearize_tnode {
    my ($tnode, $true_ids, $pred_ids, $scores) = @_;

    my $word = "";
    
    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        $word = $anode->form;
    }
    else {
        $word = $tnode->t_lemma .".". $tnode->functor;
    }
    $word =~ s/ /_/g;
    $word =~ s/\[/&osb;/g;
    $word =~ s/\]/&csb;/g;

    # only highlighting some nodes if no predicted nodes were given
    if (!defined $pred_ids) {
        if ($true_ids->{$tnode->id}) {
            $word = color('on_blue') . $word . color('reset');
        }
    }
    else {
        if ($true_ids->{$tnode->id} && $pred_ids->{$tnode->id}) {
            $word = color('green') . $word . color('reset');
        }
        elsif ($true_ids->{$tnode->id}) {
            $word = color('on_red') . $word . color('reset');
        }
        elsif ($pred_ids->{$tnode->id}) {
            $word = color('red') . $word . color('reset');
        }
    }

    if (defined $scores) {
        my $score = $scores->{$tnode->id};
        $word .= color('yellow') . $score . color('reset');
    }
    return $word;
}

sub _linearize_ttree {
    my ($ttree, $true_ids, $pred_ids, $scores) = @_;

    my @words = map {_linearize_tnode($_, $true_ids, $pred_ids, $scores)} $ttree->get_descendants({ordered => 1});
    return join " ", @words;
}

sub _linearize_ttree_structured {
    my ($ttree, $true_ids, $pred_ids, $scores) = @_;
    
    my ($sub_root) = $ttree->get_children({ordered => 1});
    my $str = _linearize_subtree_recur($sub_root, $true_ids, $pred_ids, $scores);
    return $str;
}

sub _linearize_subtree_recur {
    my ($subtree, $true_ids, $pred_ids, $scores) = @_;
    
    my $str = _linearize_tnode($subtree, $true_ids, $pred_ids, $scores);
    my @childs = $subtree->get_children({ordered => 1});
    if (@childs) {
        $str .= " [ ";
        my @child_strs = map {_linearize_subtree_recur($_, $true_ids, $pred_ids, $scores)} @childs;
        $str .= join " ", @child_strs;
        $str .= " ]";
    }
    return $str;
}

sub _process_node {
    my ($self, $l1_node) = @_;
    
    my ($l2_true_nodes, $true_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($l1_node, $self->_true_align_filter);
    my ($l2_pred_nodes, $pred_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($l1_node, $self->_pred_align_filter);

    my %l2_true_ids = map {$_->id => 1} @$l2_true_nodes;
    my %l2_pred_ids = map {$_->id => 1} @$l2_pred_nodes;

    my @intersect_keys = grep {$l2_true_ids{$_}} keys %l2_pred_ids;
    # skip if the results of true and pred are exactly the same
    return if (
        (scalar @intersect_keys == scalar keys %l2_pred_ids) &&
        (scalar @intersect_keys == scalar keys %l2_true_ids));

    my $l1_zone = $l1_node->get_zone;
    my $l2_zone = $l1_node->get_bundle->get_zone($self->align_language, $self->selector);

    my $l1_lang = uc($l1_zone->language);
    my $l2_lang = uc($l2_zone->language);

    my $scores = $l1_node->wild->{align_supervised_scores};

    print {$self->_file_handle} $l1_node->get_address . "\n";
    print {$self->_file_handle} $l1_lang .":\t" . $l1_zone->sentence . "\n";
    print {$self->_file_handle} $l2_lang .":\t" . $l2_zone->sentence . "\n";
    #print {$self->_file_handle} $l1_lang ."_T:\t" . _linearize_ttree($l1_zone->get_ttree, $l1_node) . "\n";
    print {$self->_file_handle} $l1_lang ."_TT:\t" . _linearize_ttree_structured($l1_zone->get_ttree, { $l1_node->id => 1 }, undef, $scores ) . "\n";
    #print {$self->_file_handle} $l2_lang ."_T:\t" . _linearize_ttree($l2_zone->get_ttree, $l2_node) . "\n";
    print {$self->_file_handle} $l2_lang ."_TT:\t" . _linearize_ttree_structured($l2_zone->get_ttree, \%l2_true_ids, \%l2_pred_ids, $scores ) . "\n";
    print {$self->_file_handle} "\n";
}

sub process_filtered_tnode {
    my ($self, $l1_tnode) = @_;
    $self->_process_node($l1_tnode);
}

1;

__END__

=head1 NAME

Treex::Block::Align::T::Compare

=head1 SYNOPSIS

 treex
    Read::Treex from=sample.treex.gz
    Align::T::Compare language=en align_language=cs true_alig_type='gold' pred_align_type='supervised'
 | less -SR
 
=head1 DESCRIPTION

This block serves for comparison and diagnostics of two types of
node alignment, specified by the parameters C<true_align_type> and
C<pred_align_type> (e.g., the C<gold> vs. C<supervised> type).
For every t-node in focus (specified by the parameter C<node_types>),
this block prints out the sentence in the source language C<language>
and its translation in the language C<align_language>. Furthermore,
the linearized representations of its t-trees are also printed out
with the source t-node and the aligned node higlighted in colors.
The meaning of the colors is the following:

=over
=item on blue - the source t-node
=item green - both alignment types refer to this node
=item red - only the C<pred_align_type> alignment refers to this node
=item on red - only the C<true_align_type> alignment refers to this node
=back

If the source t-node contains a wild attribute C<align_supervised_scores>,
the alignment score for each word in the target sentence is printed next
to it in yellow (see more in C<Treex::Block::Align::T::Supervised::Resolver>).

=head1 PARAMETERS

=over

=item language

Specifies the source language of the compared alignments.

=item align_language

Specifies the target language of the compared alignments.

=item node_types

A comma-separated list of the node types to be in focus (see more in C<Treex::Block::Filter::Node::T>)

=item true_align_type, pred_align_type

The comma-separated lists of types of alignment links to be compared.
The format of the lists must satisfy the format required by the C<rel_types> 
parameter in C<Treex::Tool::Align::Utils>.

=back

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

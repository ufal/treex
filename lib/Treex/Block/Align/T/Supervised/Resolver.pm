package Treex::Block::Align::T::Supervised::Resolver;

use Moose;
use Treex::Core::Common;

use List::Util qw/max/;
use sort 'stable';

use Treex::Tool::Align::Utils;
use Treex::Tool::ML::VowpalWabbit::Ranker;

extends 'Treex::Core::Block';
with 'Treex::Block::Align::T::Supervised::Base';

has 'model_path' => (is => 'ro', isa => 'Str');
has 'align_trg_lang' => ( is => 'ro', isa => 'Treex::Type::LangCode', default => sub {my $self = shift; $self->language } );
has 'align_name' => ( is => 'ro', isa => 'Str', default => 'coref_supervised' );
has 'delete_orig_align' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'skip_annotated' => ( is => 'ro', isa => 'Bool', default => 0 );

has '_model_paths' => (is => 'ro', isa => 'HashRef[HashRef[Str]]', lazy => 1, builder => '_build_model_paths');
has '_rankers' => (is => 'ro', isa => 'HashRef[HashRef[Treex::Tool::ML::VowpalWabbit::Ranker]]', builder => '_build_rankers', lazy => 1);
has '_links' => ( is => 'rw', isa => 'HashRef[HashRef[Str]]', default => sub { {} } );
has '_processed_nodes' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

sub BUILD {
    my ($self) = @_;
    $self->_model_paths;
    $self->_rankers;
}

sub _build_model_paths {
    my ($self) = @_;

    my $default_paths = {
        en => {
            cs => 'data/models/align/supervised/en_cs.all_anaph.train.model',
        },
        cs => {
            en => 'data/models/align/supervised/cs_en.all_anaph.train.model',
        }
    };
    if ($self->language eq "all") {
        log_fatal "[".(ref $self)."] Cannot use 'all' as a value for the 'language' parameter. Specify the languages in a comma-separated list.";
    }
    my @langs = split /,/, $self->language;
    if (@langs != 2) {
        log_fatal "[".(ref $self)."] Exactly two languages must be specified in a comma-separated list.";
    }
    my $model_paths = {};
    if ($self->model_path) {
        my @lang_paths = split /,/, $self->model_path;
        if (@lang_paths != 2) {
            log_fatal "[".(ref $self)."] To model paths in a comma-separated list must be specified. One of the values may be empty, if you do not want to apply the either forward or backward alignment model.";
        }
        $model_paths->{$langs[0]}{$langs[1]} = $lang_paths[0];
        $model_paths->{$langs[1]}{$langs[0]} = $lang_paths[1];
    }
    else {
        $model_paths->{$langs[0]}{$langs[1]} = $default_paths->{$langs[0]}{$langs[1]};
        $model_paths->{$langs[1]}{$langs[0]} = $default_paths->{$langs[1]}{$langs[0]};
    }
    return $model_paths;
}

sub _build_rankers {
    my ($self) = @_;
    my $rankers = {};
    my $model_paths = $self->_model_paths;
    foreach my $lang (keys %$model_paths) {
        foreach my $ali_lang (keys %{$model_paths->{$lang}}) {
            my $path = $self->_model_paths->{$lang}{$ali_lang};
            if ($path !~ /^\s*$/) {
                $rankers->{$lang}{$ali_lang} = Treex::Tool::ML::VowpalWabbit::Ranker->new({model_path => $path});
            }
        }
    }
    return $rankers;
}


sub _add_link {
    my ($self, $n1, $n2, $score) = @_;

    my ($n1_id, $n2_id) = map {$_->id} ($n1, $n2);
    my $links = $self->_links;
    
    my $scores = $links->{$n1_id}{$n2_id} // [];
    push @$scores, $score;
    $links->{$n1_id}{$n2_id} = $scores;
    $links->{$n2_id}{$n1_id} = $scores;
}

sub _finalize_links {
    my ($self, $bundle) = @_;
    # links contains symmetrized decisions of the two resolvers
    # links->{A}{A} means that the node A is unaligned
    my $links = $self->_links;

    my @two_score_links = ();
    my @one_score_links = ();
    my @one_score_scores = ();
    
    foreach my $from_id (sort keys %$links) {
        my $from_node = $bundle->get_document->get_node_by_id($from_id);
        foreach my $to_id (sort keys %{$links->{$from_id}}) {
            my $to_node = $bundle->get_document->get_node_by_id($to_id);
            next if ($from_id ne $to_id && $from_node->language eq $self->align_trg_lang);
            
            if (scalar @{$links->{$from_id}{$to_id}} > 1) {
                push @two_score_links, [$from_node, $to_node];
            }
            else {
                push @one_score_links, [$from_node, $to_node];
                push @one_score_scores, $links->{$from_id}{$to_id}[0];
            }
        }
    }

    my @one_score_sorted_idx = sort {$one_score_scores[$b] <=> $one_score_scores[$a]} 0 .. $#one_score_scores;
    my @sorted_one_score_links = map {$one_score_links[$_]} @one_score_sorted_idx;

    my %covered_ids = ();
    foreach my $list (\@two_score_links, \@sorted_one_score_links) {
        foreach my $pair (@$list) {
            my $from_node = $pair->[0];
            my $to_node = $pair->[1];

            if ($covered_ids{$from_node->id}) {
                log_info "[".(ref $self)."] Alignment link ".$from_node->id." --> ".$to_node->id." skipped. The node ".$from_node->id." already covered.";
            }
            elsif ($covered_ids{$to_node->id}) {
                log_info "[".(ref $self)."] Alignment link ".$from_node->id." --> ".$to_node->id." skipped. The node ".$to_node->id." already covered.";
            }
            else {
                if ($from_node != $to_node) {
                    log_info "[".(ref $self)."] Adding alignment: " . $from_node->id . " --> " . $to_node->id;
                    Treex::Tool::Align::Utils::add_aligned_node($from_node, $to_node, $self->align_name);
                }
                $covered_ids{$from_node->id} = 1;
                $covered_ids{$to_node->id} = 1;
            }
        }
    }
}

sub _remove_old_links {
    my ($self) = @_;

    if ($self->delete_orig_align) {
        foreach my $tnode (@{$self->_processed_nodes}) {
            $tnode->delete_aligned_nodes_by_filter({
                language => $self->_get_align_lang($tnode->language),
                selector => $self->selector, 
                rel_types => ['!gold','.*'],
            });
        }
    }
}

after 'process_bundle' => sub {
    my ($self, $bundle) = @_;

    $self->_remove_old_links();
    $self->_finalize_links($bundle);
    $self->_set_links({});
    $self->_set_processed_nodes([]);
};

sub _get_align_lang {
    my ($self, $lang) = @_;
    my ($align_lang) = keys %{$self->_model_paths->{$lang}};
    return $align_lang;
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;

    return if ($self->skip_annotated && $tnode->get_attr('is_align_coref'));
    
    my $lang = $tnode->language;
    my $align_lang = $self->_get_align_lang($lang);
    my $ranker = $self->_rankers->{$lang}{$align_lang};
    return if (!defined $ranker);
    
    my @cands = $self->_get_candidates($tnode, $align_lang);
    if (@cands > 100) {
        log_warn "[".(ref $self)."] More than 100 alignment candidates.";
        return;
    }
    my $feats = $self->_feat_extractor->create_instances($tnode, ["__SELF__"], \@cands);
    my ($winner_idx, $winner_score);
    if (Treex::Core::Log::get_error_level() eq 'DEBUG') {
        log_info "ALIGN SUPERVISED DEBUG ZONE";
        my @scores = $ranker->rank($feats);
        $tnode->wild->{align_supervised_scores} = { map {$cands[$_]->id => $scores[$_]} 0 .. $#cands };
        $winner_score = max @scores;
        ($winner_idx) = grep {$scores[$_] == $winner_score} 0 .. $#scores;
    }
    else {
        ($winner_idx, $winner_score) = $ranker->pick_winner($feats);
    }

    push @{$self->_processed_nodes}, $tnode;

    $tnode->set_attr('is_align_coref', 1);
    $self->_add_link($tnode, $cands[$winner_idx], $winner_score);
}

1;

__END__

=head1 NAME

Treex::Block::Align::T::Supervised::Resolver

=head1 SYNOPSIS

 treex
    Read::Treex from=sample.treex.gz
    Align::T::Supervised::Resolver language=en,cs align_trg_lang=en delete_orig_align=0
 
=head1 DESCRIPTION

Supervised resolver for alignment. For a defined language pair (parameter C<language>),
the block applies a single or both directional alignment models (paramter C<model_path>)
trained in Vowpal Wabbit on specified nodes (parameter C<node_types>). Since the PML 
representation of the alignment link is also directional, the target alignment language 
(parameter C<align_trg_lang>) must be specified. By default, the original alignment 
of the source and target node is deleted (parameter C<delete_orig_align>).

=head1 PARAMETERS

=over

=item language

A comma-separated list of the languages between which alignment is to be resolved.
The list must contain exactly two items. The value C<all> is not allowed.

=item model_path

A comma-separated list of paths to models. The list must consist of two items corresponding
to the forward, and the backward alignment model. The forward model is expected to be trained
in the direction of the language pair as specified in C<language>, while the backward model
in the opposite direction. 
If one of the models is ommitted, only a single model in the specified direction is used.
If the parameter is undefined, use default values.

=item node_types

A comma-separated list of the node types on which this block should be applied (see more 
in C<Treex::Block::Filter::Node>).

=item align_trg_lang

As alignment links in PML are directional, their direction must be determined by specifying
the target language.

=item delete_orig_align

If a new alignment link is found, the original links the source or target node are involved
in are deleted (by default).

=back

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

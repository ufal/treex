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
    my ($self, $n1, $n2) = @_;

    my ($n1_id, $n2_id) = map {$_->id} ($n1, $n2);
    my $links = $self->_links;
    
    $links->{$n1_id}{$n2_id}++;
    $links->{$n2_id}{$n1_id}++;
}

sub _finalize_links {
    my ($self, $bundle) = @_;
    my $links = $self->_links;

    my @possible_links = ();
    my @links_scores = ();
    
    foreach my $from_id (sort keys %$links) {
        my $from_node = $bundle->get_document->get_node_by_id($from_id);
        foreach my $to_id (sort keys %{$links->{$from_id}}) {
            my $to_node = $bundle->get_document->get_node_by_id($to_id);
            next if ($from_id ne $to_id && $from_node->language eq $self->align_trg_lang);
            push @possible_links, [$from_node, $to_node];
            push @links_scores, $links->{$from_id}{$to_id};
        }
    }

    my @sorted_idx = sort {$links_scores[$b] <=> $links_scores[$a]} 0 .. $#links_scores;

    my %covered_ids = ();
    foreach my $idx (@sorted_idx) {
        my $from_node = $possible_links[$idx]->[0];
        my $to_node = $possible_links[$idx]->[1];

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

after 'process_bundle' => sub {
    my ($self, $bundle) = @_;

    $self->_finalize_links($bundle);
    $self->_set_links({});
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
    my $feats = $self->_feat_extractor->create_instances($tnode, \@cands);
    my $winner_idx;
    if (Treex::Core::Log::get_error_level() eq 'DEBUG') {
        log_info "ALIGN SUPERVISED DEBUG ZONE";
        my @scores = $ranker->rank($feats);
        $tnode->wild->{align_supervised_scores} = { map {$cands[$_]->id => $scores[$_]} 0 .. $#cands };
        my $max = max @scores;
        ($winner_idx) = grep {$scores[$_] == $max} 0 .. $#scores;
    }
    else {
        $winner_idx = $ranker->pick_winner($feats);
    }

    if ($self->delete_orig_align) {
        $tnode->delete_aligned_nodes_by_filter({
            language => $self->_get_align_lang($tnode->language),
            selector => $self->selector, 
            rel_types => ['!gold','.*'],
        });
    }
    $tnode->set_attr('is_align_coref', 1);
    $self->_add_link($tnode, $cands[$winner_idx]);
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

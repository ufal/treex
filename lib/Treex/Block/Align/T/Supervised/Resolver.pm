package Treex::Block::Align::T::Supervised::Resolver;

use Moose;
use Treex::Core::Common;

use List::Util qw/max/;

use Treex::Tool::Align::Utils;
use Treex::Tool::ML::VowpalWabbit::Ranker;

extends 'Treex::Core::Block';
with 'Treex::Block::Align::T::Supervised::Base';
with 'Treex::Block::Filter::Node::T';

has '+node_types' => ( default => 'all_anaph' );
has 'model_path' => (is => 'ro', isa => 'Str');
has 'align_trg_lang' => ( is => 'ro', isa => 'Treex::Type::LangCode', default => sub {my $self = shift; $self->language } );

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
    
    print STDERR "trying to add link: $n1_id <-> $n2_id\n";

    if (defined $links->{$n1_id}) {
        if (!defined $links->{$n1_id}{$n2_id}) {
            log_warn "[".(ref $self)."] Trying to add alignment link to the already aligned node ".$n1->get_address.".";
        }
    }
    elsif (defined $links->{$n2_id}) {
        if (!defined $links->{$n2_id}{$n1_id}) {
            log_warn "[".(ref $self)."] Trying to add alignment link to the already aligned node ".$n2->get_address.".";
        }
    }
    else {
        $links->{$n1_id}{$n2_id} = 1;
        $links->{$n2_id}{$n1_id} = 1;
    }
}

after 'process_bundle' => sub {
    my ($self, $bundle) = @_;

    my $links = $self->_links;

    print STDERR Dumper($links);

    foreach my $from_id (keys %$links) {
        my $from_node = $bundle->get_document->get_node_by_id($from_id);
        next if ($from_node->language eq $self->align_trg_lang);
        Treex::Tool::Align::Utils::remove_aligned_nodes_by_filter($from_node, {language => $self->align_trg_lang, selector => $self->selector, rel_types => ['!gold']});
        foreach my $to_id (keys %{$links->{$from_id}}) {
            my $to_node = $bundle->get_document->get_node_by_id($to_id);
            # skip if referring to itself => no alignment detected
            next if ($from_node == $to_node);
            log_info "[".(ref $self)."] Adding alignment: " . $from_id . " --> " . $to_id;
            Treex::Tool::Align::Utils::add_aligned_node($from_node, $to_node, "supervised");
            #print STDERR join " ", map {$_->id eq $from_id ? "<".$_->t_lemma.">" : $_->t_lemma} $from_node->get_root->get_descendants({ordered => 1});
            #print STDERR "\n";
            #print STDERR join " ", map {$_->id eq $to_id ? "<".$_->t_lemma.">" : $_->t_lemma} $to_node->get_root->get_descendants({ordered => 1});
            #print STDERR "\n";
        }
    }

    $self->_set_links({});
};

sub _get_align_lang {
    my ($self, $lang) = @_;
    my ($align_lang) = keys %{$self->_model_paths->{$lang}};
    return $align_lang;
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    
    my $lang = $tnode->language;
    my $align_lang = $self->_get_align_lang($lang);
    my $ranker = $self->_rankers->{$lang}{$align_lang};
    return if (!defined $ranker);
    
    my @cands = $self->_get_candidates($tnode, $align_lang);
    if (@cands > 100) {
        log_warn "[Block::My::AlignmentResolver]\tMore than 100 alignment candidates.";
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

    $self->_add_link($tnode, $cands[$winner_idx]);
}

1;

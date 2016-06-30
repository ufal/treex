package Treex::Tool::UDPipe;
# TODO: code duplication with Udapi::Tool::UDPipe
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Ufal::UDPipe;


has model => ( is => 'ro', isa => 'Str', required => 1 );
has _model_absolute_path => ( is => 'ro', isa => 'Str', lazy_build => 1 );

sub _build__model_absolute_path {
    my ($self) = @_;
    return Treex::Core::Resource::require_file_from_share($self->model);
}

# Instance of Ufal::UDPipe::Model
has tool => (is=>'ro', lazy_build=>1);
has tokenizer => (is=>'ro', lazy_build=>1);

# tool can be shared by more instances (if the model file is the same)
my %TOOL_FOR_PATH;
sub _build_tool {
    my ($self) = @_;
    my $path = $self->_model_absolute_path;
    my $tool = $TOOL_FOR_PATH{$path};
    return $tool if $tool;
    log_info("Loading Ufal::UDPipe::Model with model '$path'");
    $tool = Ufal::UDPipe::Model::load($path)
        or log_fatal("Cannot load Ufal::UDPipe::Model with model from file '$path'");
    $TOOL_FOR_PATH{$path} = $tool;
    return $tool;
}

sub _build_tokenizer {
    my ($self) = @_;
    return $self->tool->newTokenizer($Ufal::UDPipe::Model::DEFAULT);
}

# Note that the variables with prefix "udpipe_"
# are not normal Perl variables, but Swig-magic tied hashes.
# So we can to use only the methods specified in UDPipe API to work with them.

sub tokenize_string {
    my ($self, $string) = @_;
    my $udpipe_sentence = Ufal::UDPipe::Sentence->new();
    my @forms;
    my $tokenizer = $self->tokenizer;
    $tokenizer->setText($string);
    while ($tokenizer->nextSentence($udpipe_sentence)) {
        my $udpipe_words = $udpipe_sentence->{words};
        for my $i (1 .. $udpipe_words->size-1){
           my $udpipe_word = $udpipe_words->get($i);
           push @forms, $udpipe_word->{form};
           # TODO $udpipe_word->{misc} eq 'SpaceAfter=No'
         }
    }
    return @forms;
}

sub tokenize_tree {
    my ($self, $root) = @_;
    my $udpipe_sentence = Ufal::UDPipe::Sentence->new();
    my $tokenizer = $self->tokenizer;
    $tokenizer->setText($root->get_zone()->sentence);
    while ($tokenizer->nextSentence($udpipe_sentence)) {
        my $udpipe_words = $udpipe_sentence->{words};
        for my $i (1 .. $udpipe_words->size-1){
           my $uw = $udpipe_words->get($i);
           $root->create_child(
               form=>$uw->{form},
               no_space_after=> ($uw->{misc} eq 'SpaceAfter=No'),
               ord=>$i);
         }
    }
    return;
}

sub tag_nodes {
    my ($self, @nodes) = @_;
    my $udpipe_sentence = Ufal::UDPipe::Sentence->new();
    my $tool = $self->tool;
    foreach my $form (map {$_->form} @nodes) {
        $udpipe_sentence->addWord($form);
    }

    $tool->tag($udpipe_sentence, $Ufal::UDPipe::Model::DEFAULT);

    my $udpipe_words = $udpipe_sentence->{words};
    for my $i (1 .. $udpipe_words->size-1){
       my $udpipe_word = $udpipe_words->get($i);
       my $node = $nodes[$i-1];
       $node->set_conll_cpos($udpipe_word->{upostag});
       $node->set_conll_pos($udpipe_word->{xpostag});
       $node->set_lemma($udpipe_word->{lemma});
       $node->set_conll_feat($udpipe_word->{feats});
     }
     return;
}

sub tag_tree {
    my ($self, $root) = @_;
    $self->tag_nodes($root->get_descendants({ordered=>1}));
    return;
}

sub tokenize_tag_tree {
    my ($self, $root) = @_;
    $self->tokenize_tree($root);
    $self->tag_tree($root);
    return;
}

sub parse_tree {
    my ($self, $root) = @_;

    # converting Treex nodes to UDPipe nodes
    my $udpipe_sentence = Ufal::UDPipe::Sentence->new();
    my @nodes = $root->get_descendants({ordered=>1});
    foreach my $node (@nodes) {
        my $uw = $udpipe_sentence->addWord($node->form);
        $uw->{lemma}   = $node->lemma;
        $uw->{upostag} = $node->conll_cpos;
        $uw->{xpostag} = $node->conll_pos;
        $uw->{feats}   = $node->conll_feat;
    }

    # parsing
    my $tool = $self->tool;
    $tool->parse($udpipe_sentence, $Ufal::UDPipe::Model::DEFAULT);

    # converting UDPipe nodes to Treex nodes
    my $udpipe_words = $udpipe_sentence->{words};
    my @heads;
    my @all_nodes = ($root, @nodes);
    foreach my $node (@nodes){
        $node->set_parent($root);
    }
    for my $i (1 .. $udpipe_words->size-1){
        my $uw = $udpipe_words->get($i);
        my $node = $all_nodes[$i];
        $node->set_parent($all_nodes[$uw->{head}]);
        $node->set_deprel($uw->{deprel});
        $node->set_conll_deprel($uw->{deprel});
    }
    return;
}


sub tag_parse_tree {
    my ($self, @nodes) = @_;
    my $udpipe_sentence = Ufal::UDPipe::Sentence->new();
    my $tool = $self->tool;
    foreach my $form (map {$_->form} @nodes) {
        $udpipe_sentence->addWord($form);
    }

    $tool->tag($udpipe_sentence, $Ufal::UDPipe::Model::DEFAULT);

    my $udpipe_words = $udpipe_sentence->{words};
    for my $i (1 .. $udpipe_words->size-1){
       my $udpipe_word = $udpipe_words->get($i);
       my $node = $nodes[$i-1];
       $node->set_conll_cpos($udpipe_word->{upostag});
       $node->set_conll_pos($udpipe_word->{xpostag});
       $node->set_lemma($udpipe_word->{lemma});
       $node->set_conll_feat($udpipe_word->{feats});
     }
     return;
}

sub tokenize_tag_parse_tree {
    my ($self, $root) = @_;
    my $string = $root->get_zone()->sentence;
    log_fatal 'called on non-empty tree' if $root->get_children;
    log_fatal 'empty sentence' if !length $string;

    # tokenization (I cannot turn off segmenter, so I need to join the segments)
    my $tokenizer = $self->tokenizer;
    $tokenizer->setText($string);
    my $udpipe_sentence = Ufal::UDPipe::Sentence->new();
    my $is_another = $tokenizer->nextSentence($udpipe_sentence) ;
    my $udpipe_words = $udpipe_sentence->{words};
    my $n_words = $udpipe_words->size - 1;
    if ($is_another) {
        my $udpipe_sent_cont = Ufal::UDPipe::Sentence->new();
        while ($tokenizer->nextSentence($udpipe_sent_cont)) {
            my $udpipe_words_cont = $udpipe_sent_cont->{words};
            my $n_cont = $udpipe_words_cont->size - 1;
            for my $i (1 .. $n_cont){
                my $udpipe_word = $udpipe_words_cont->get($i);
                $udpipe_word->{id} = ++$n_words;
                $udpipe_words->push($udpipe_word);
            }
        }
    }

    # tagging and parsing
    my $tool = $self->tool;
    $tool->tag($udpipe_sentence, $Ufal::UDPipe::Model::DEFAULT);
    $tool->parse($udpipe_sentence, $Ufal::UDPipe::Model::DEFAULT);

    # converting UDPipe nodes to Treex nodes
    my (@heads, @nodes);
    for my $i (1 .. $udpipe_words->size-1){
        my $uw = $udpipe_words->get($i);
        my $node = $root->create_child(
            form=>$uw->{form}, lemma=>$uw->{lemma}, tag=>$uw->{upostag},
            deprel=>$uw->{deprel}, ord=>$i,
            #deps=>$uw->{deps}, misc=>$uw->{misc},
        );
        $node->set_conll_cpos($uw->{upostag});
        $node->set_conll_pos($uw->{xpostag});
        $node->set_conll_feat($uw->{feats});
        $node->set_conll_deprel($uw->{deprel});
        push @heads, $uw->{head};
        push @nodes, $node;
    }
    my @all_nodes = ($root, @nodes);
    foreach my $node (@nodes){
        $node->set_parent($all_nodes[shift @heads]);
    }
    return;
}

1;

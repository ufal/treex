package Treex::Tool::UDPipe;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Ufal::UDPipe;

has model                => ( is => 'ro', isa => 'Str', required   => 1 );
has _model_absolute_path => ( is => 'ro', isa => 'Str', lazy_build => 1 );

sub _build__model_absolute_path {
    my ($self) = @_;
    return Treex::Core::Resource::require_file_from_share( $self->model );
}

# Instance of Ufal::UDPipe::Model
has tool      => ( is => 'ro', lazy_build => 1 );
has tokenizer => ( is => 'ro', lazy_build => 1 );

# tool can be shared by more instances (if the model file is the same)
my %TOOL_FOR_PATH;

sub _build_tool {
    my ($self) = @_;
    my $path   = $self->_model_absolute_path;
    my $tool   = $TOOL_FOR_PATH{$path};
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

# Note that the variables with prefix "u_"
# are not normal Perl variables, but Swig-magic tied hashes.
# So we can use only the methods specified in UDPipe API to work with the variables.

sub tokenize_string {
    my ( $self, $string ) = @_;
    my $u_sentence = Ufal::UDPipe::Sentence->new();
    my @forms;
    my $tokenizer = $self->tokenizer;
    $tokenizer->setText($string);
    while ( $tokenizer->nextSentence($u_sentence) ) {
        my $u_words = $u_sentence->{words};
        for my $i ( 1 .. $u_words->size - 1 ) {
            my $u_w = $u_words->get($i);
            push @forms, $u_w->{form};
        }
    }
    return @forms;
}

sub tokenize_tree {
    my ( $self, $root ) = @_;
    my $u_sentence = Ufal::UDPipe::Sentence->new();
    my $tokenizer  = $self->tokenizer;
    $tokenizer->setText( $root->get_zone()->sentence );
    while ( $tokenizer->nextSentence($u_sentence) ) {
        my $u_words = $u_sentence->{words};
        for my $i ( 1 .. $u_words->size - 1 ) {
            my $u_w = $u_words->get($i);
            $root->create_child(
                form           => $u_w->{form},
                no_space_after => ( $u_w->{misc} eq 'SpaceAfter=No' ),
                ord            => $i
            );
        }
    }
    return;
}

sub tag_nodes {
    my ( $self, @nodes ) = @_;
    my $u_sentence = Ufal::UDPipe::Sentence->new();
    my $tool       = $self->tool;
    foreach my $form ( map { $_->form } @nodes ) {
        $u_sentence->addWord($form);
    }

    $tool->tag( $u_sentence, $Ufal::UDPipe::Model::DEFAULT );

    my $u_words = $u_sentence->{words};
    for my $i ( 1 .. $u_words->size - 1 ) {
        my $u_w  = $u_words->get($i);
        my $node = $nodes[ $i - 1 ];
        $node->set_conll_cpos( $u_w->{upostag} );
        $node->set_conll_pos( $u_w->{xpostag} );
        $node->set_lemma( $u_w->{lemma} );
        $node->set_conll_feat( $u_w->{feats} );
    }
    return;
}

sub tag_tree {
    my ( $self, $root ) = @_;
    $self->tag_nodes( $root->get_descendants( { ordered => 1 } ) );
    return;
}

sub tokenize_tag_tree {
    my ( $self, $root ) = @_;
    $self->tokenize_tree($root);
    $self->tag_tree($root);
    return;
}

sub parse_tree {
    my ( $self, $root ) = @_;

    # converting Treex nodes to UDPipe nodes
    my $u_sentence = Ufal::UDPipe::Sentence->new();
    my @nodes = $root->get_descendants( { ordered => 1 } );
    foreach my $node (@nodes) {
        my $u_w = $u_sentence->addWord( $node->form );
        $u_w->{lemma}   = $node->lemma;
        $u_w->{upostag} = $node->conll_cpos;
        $u_w->{xpostag} = $node->conll_pos;
        $u_w->{feats}   = $node->conll_feat;
    }

    # parsing
    my $tool = $self->tool;
    $tool->parse( $u_sentence, $Ufal::UDPipe::Model::DEFAULT );

    # converting UDPipe nodes to Treex nodes
    my $u_words = $u_sentence->{words};
    my @heads;
    my @all_nodes = ( $root, @nodes );
    foreach my $node (@nodes) {
        $node->set_parent($root);
    }
    for my $i ( 1 .. $u_words->size - 1 ) {
        my $u_w  = $u_words->get($i);
        my $node = $all_nodes[$i];
        $node->set_parent( $all_nodes[ $u_w->{head} ] );
        $node->set_deprel( $u_w->{deprel} );
        $node->set_conll_deprel( $u_w->{deprel} );
    }
    return;
}

sub tag_parse_tree {
    my ( $self, $root ) = @_;
    my $u_sentence = Ufal::UDPipe::Sentence->new();
    my @nodes = $root->get_descendants( { ordered => 1 } );
    foreach my $node (@nodes) {
        my $form = $node->form;
        log_fatal 'Undefined form of ' . $node->get_address() if !defined $form;
        $u_sentence->addWord($form);
    }

    my $tool = $self->tool;
    $tool->tag( $u_sentence, $Ufal::UDPipe::Model::DEFAULT );
    $tool->parse( $u_sentence, $Ufal::UDPipe::Model::DEFAULT );

    my @heads;
    my $u_words = $u_sentence->{words};
    for my $i ( 1 .. $u_words->size - 1 ) {
        my $u_w  = $u_words->get($i);
        my $node = $nodes[ $i - 1 ];
        $node->set_conll_cpos( $u_w->{upostag} );
        $node->set_conll_pos( $u_w->{xpostag} );
        $node->set_lemma( $u_w->{lemma} );
        $node->set_conll_feat( $u_w->{feats} );
        $node->set_deprel( $u_w->{deprel} );
        $node->set_conll_deprel( $u_w->{deprel} );
        push @heads, $u_w->{head};
    }
    my @all_nodes = ( $root, @nodes );
    foreach my $node (@nodes) {
        $node->set_parent( $all_nodes[ shift @heads ] );
    }
    return;
}

sub tokenize_tag_parse_tree {
    my ( $self, $root ) = @_;
    my $string = $root->get_zone()->sentence;
    log_fatal 'called on non-empty tree' if $root->get_children;
    log_fatal 'empty sentence' if !length $string;

    # tokenization (I cannot turn off segmenter, so I need to join the segments)
    my $tokenizer = $self->tokenizer;
    $tokenizer->setText($string);
    my $u_sentence = Ufal::UDPipe::Sentence->new();
    my $is_another = $tokenizer->nextSentence($u_sentence);
    my $u_words    = $u_sentence->{words};
    my $n_words    = $u_words->size - 1;
    if ($is_another) {
        my $u_sent_cont = Ufal::UDPipe::Sentence->new();
        while ( $tokenizer->nextSentence($u_sent_cont) ) {
            my $u_words_cont = $u_sent_cont->{words};
            my $n_cont       = $u_words_cont->size - 1;
            for my $i ( 1 .. $n_cont ) {
                my $u_w = $u_words_cont->get($i);
                $u_w->{id} = ++$n_words;
                $u_words->push($u_w);
            }
        }
    }

    # tagging and parsing
    my $tool = $self->tool;
    $tool->tag( $u_sentence, $Ufal::UDPipe::Model::DEFAULT );
    $tool->parse( $u_sentence, $Ufal::UDPipe::Model::DEFAULT );

    # converting UDPipe nodes to Treex nodes
    my ( @heads, @nodes );
    for my $i ( 1 .. $u_words->size - 1 ) {
        my $u_w  = $u_words->get($i);
        my $node = $root->create_child(
            form           => $u_w->{form},
            lemma          => $u_w->{lemma},
            tag            => $u_w->{upostag},
            deprel         => $u_w->{deprel},
            ord            => $i,
            no_space_after => ( $u_w->{misc} eq 'SpaceAfter=No' ),
            #deps=>$u_w->{deps}, misc=>$u_w->{misc},
        );
        $node->set_conll_cpos( $u_w->{upostag} );
        $node->set_conll_pos( $u_w->{xpostag} );
        $node->set_conll_feat( $u_w->{feats} );
        $node->set_conll_deprel( $u_w->{deprel} );
        push @heads, $u_w->{head};
        push @nodes, $node;
    }
    my @all_nodes = ( $root, @nodes );
    foreach my $node (@nodes) {
        $node->set_parent( $all_nodes[ shift @heads ] );
    }
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::UDPipe - wrapper for Ufal::UDPipe

=head1 SYNOPSIS

 use Treex::Tool::UDPipe;
 my $udpipe = Treex::Tool::UDPipe->new(
    model => 'data/models/udpipe/english-ud-1.2-160523.udpipe',
 );

 my @forms = $udpipe->tokenize_string(q{I don't know.});

 my $root = $zone->create_atree();
 $zone->set_sentence(q{I don't know.});
 $udapi->tokenize_tree($root);

 my @nodes = $root->get_descendants({ordered=>1});
 $udapi->tag_nodes(@nodes);

 $udapi->tag_tree($root);

 $udapi->tokenize_tag_tree($root);

 $udapi->parse_tree($root);

 $udapi->tag_parse_tree($root);

 $udapi->tokenize_tag_parse_tree($root);

=head1 DESCRIPTION

Wrapper for state-of-the-art linguistic analyzer UDPipe,
written in C++ by Milan Straka.
I does analysis into the Universal Dependencies (UD) style including
tokenization, tagging (plus lemmatization and universal features)
and parsing (with deprel labels).
This tool provides a more user-friendly and perlish interface than the original
L<Ufal::UDPipe>, which is used under the hood, so it must be installed from CPAN.
There are several alternative methods how to use the tool dependenig on
which subtasks (tokenization, tagging, parsing) should be done
and whether Treex tree (or just its root) is available on the input.

Each method call has some overhead with converting the data structures,
so it is faster to call C<tokenize_tag_parse_tree> than to call separately
C<tokenize_tree>, C<tag_tree> and C<parse_treeparse_tree>.

There are pretrained models for UDPipe for many languages, see
L<https://ufal.mff.cuni.cz/udpipe/users-manual#universal_dependencies_12_models_performance>.

If you instantiate this class multiple times with the same model,
only one (shared) L<Ufal::UDPipe> instance will be created internally,
so there is almost no memory overhead caused by instantiating this class
in multiple Treex blocks.

=head1 PARAMETERS

=head2 C<model>

Path to the model file within Treex share
(or relative path starting with "./" or absolute path starting with "/").

=head1 METHODS

See the synopsis:-)

=head1 SEE ALSO

L<http://ufal.mff.cuni.cz/udpipe>

L<Treex::Block::W2A::UDPipe>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

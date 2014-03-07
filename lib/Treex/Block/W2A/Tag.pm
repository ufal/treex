package Treex::Block::W2A::Tag;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::Tagger::Service;

extends 'Treex::Core::Block';

has lemmatize => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has module => (
    is       => 'ro',
    isa      => 'Str',
    lazy_build => 1,
);

has tagger => (
    is => 'rw',
    does => 'Treex::Tool::Tagger::Role',
    lazy_build => 1,
);

has max_sentence_size => (
    is => 'ro',
    isa => 'Int',
    default => 1000,
    documentation => 'If a sentence contains more tokens, it is split and each chunk of max_sentence_size tokens is sent separately to the tagger. '
                   . 'This parameter serves as a safety check for extremely long sentences and taggers that may fail on such sentences. 0 means do not split.',
);


has _args => (is => 'rw');

sub BUILD {
    my ($self, $arg_ref) = @_;

    # We need to store parameters of this block and pass them to the tagger's constructor
    $self->_set_args($arg_ref);
    return;
}

sub _build_tagger {
    my ($self) = @_;
    my $module = $self->module;
    
    if (Treex::Core::Config->use_services && $module =~ /^Treex::Tool::Tagger::(.+)$/) {
        return Treex::Tool::Tagger::Service->new(tagger_name => $1, %{$self->_args});
    }
    
    eval "use $module;1" or log_fatal "Can't use $module\n$@";
    my $tagger = eval "$module->new(\$self->_args);" or log_fatal "Can't load $module\n$@";
    return $tagger;
}

sub _build_module {
    log_fatal 'Parameter "module" is required when using W2A::Tag directly in scenario. E.g. W2A::Tag module=Treex::Tool::Tagger::Featurama::EN';
}

sub process_start {
    my ($self) = @_;

    # tagger is build lazily, but it can involve loading huge models,
    # so it should be done now, instead of when processing the first document.
    $self->tagger;
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my @nodes = $atree->get_descendants({ordered=>1});

    # It is legal to have a tree with no nodes (e.g. for non 1-1 aligned sentences),
    # so just skip such sentences (and do not log_fatal if no lemmas are found).
    return if !@nodes;

    my $forms_rf = [map { $_->form } @nodes];
    $self->normalize($forms_rf);
    
    # Run the tagger with a safety check for extremely long sentences.
    my ( $tags_rf, $lemmas_rf ) = ([], []);
    if ( $self->max_sentence_size && @nodes > $self->max_sentence_size ) {
        my $sentence_size = @nodes;
        log_info("Sentence contains $sentence_size tokens, applying the tagger per partes.");
        my (@tags, @lemmas);
        use List::MoreUtils qw(natatime);
        my $iterator = natatime($self->max_sentence_size, @$forms_rf);
        while (my @forms_part = $iterator->()){
            my ( $tags_part_rf, $lemmas_part_rf ) = $self->tagger->tag_sentence(\@forms_part);
            push @$tags_rf, @$tags_part_rf;
            push @$lemmas_rf, @$lemmas_part_rf if $lemmas_part_rf;
        }
    }
    else {
        ( $tags_rf, $lemmas_rf ) = $self->tagger->tag_sentence($forms_rf);
    }

    # Check and fill tags
    log_fatal "Different number of tokens and tags. TOKENS: @$forms_rf, TAGS: @$tags_rf" if @$tags_rf != @nodes;
    foreach my $a_node (@nodes) {
        $a_node->set_tag( shift @$tags_rf );
    }

    # If the tagger was supposed to lemmatize, check and fill lemmas
    if ($self->lemmatize){
        log_fatal "Tagger did not return any lemmas" if !$lemmas_rf || !@$lemmas_rf;
        log_fatal "Different number of tokens and lemmas. TOKENS: @$forms_rf, LEMMAS: @$lemmas_rf" if @$lemmas_rf != @nodes;
        foreach my $a_node (@nodes) {
            my $lemma = shift @$lemmas_rf;
            if (!defined $lemma || $lemma eq ''){
                log_warn sprintf 'Tagger %s produced an empty lemma for form "%s". Using lc form. %s', ref $self, $a_node->form, $a_node->get_address;
                $lemma = lc $a_node->form;
            }
            $a_node->set_lemma($lemma);
        }
    }

    return;
}

sub normalize {
    my ($self, $forms_rf) = @_;

    # Derived classes may override this method and do some normalization.
    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::Tag - universal block for PoS tagging and lemmatization

=head1 SYNOPSIS

  # ==== from command line (W2A::Tag in scenario) ====
  echo "Hello there" | treex -t \
   W2A::Tag module=Treex::Tool::Tagger::Simple::XY lemmatize=1 \
   Write::CoNLLX

  # ==== creating a derived class ====
  package Treex::Block::W2A::XY::TagSimple;
  use Moose; use Treex::Core::Common;
  use Treex::Tool::Tagger::Simple::XY;
  extends 'Treex::Block::W2A::Tag';

  # If the tool needs a module, set a default
  has model => (is => 'ro', default => 'data/models/tagger/simple/xy.model');

  # Override the builder, so $self->tagger is an instance of Treex::Tool::Tagger::Simple::XY
  sub _build_tagger{
    my ($self) = @_;
    # $self->_args is a hashref of all parameters passed to this block (from scenario).
    # The tool usually needs just model, but this way it is easy to add new parameters
    # (e.g. mem=1g) to the tool without changing this block.
    $self->_args->{model} = $self->model;
    return Treex::Tool::Tagger::Simple::XY->new($self->_args);
  }
  1; # add POD and that's all :-)

=head1 DESCRIPTION

This class serves two purposes:

- It is a base class for all other PoS tagging blocks.

- It can be used directly in the scenario with specifying the name of the tagger tool in the parameter C<module>.

=head2 Lemmatization

Some taggers do lemmatization together with parsing. Some cannot lemmatize.
Some can choose whether to lemmatize or not and in that case the tagger may use less resources.
Therefore, this block (and derived classes) has parameter C<lemmatize>
- if set to 0, no lemmas are filled in the trees (even if returned by the tagger tool);
- if set to 1, the tagger should either lemmatize all sentences or fail (via log_fatal) during the inicialization,
if it does not support lemmatization.

=head1 SEE ALSO

L<Treex::Tool::Tagger::Role>

=head1 COPYRIGHT AND LICENCE

Copyright 2011-2012 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

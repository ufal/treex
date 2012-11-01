package Treex::Block::W2A::Tag;
use Moose;
use Treex::Core::Common;
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
    eval "use $module;1" or log_fatal "Can't use $module";
    my $tagger = eval "$module->new(\$self->_args);" or log_fatal "Can't load $module";
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
    my $forms_rf = [map { $_->form } @nodes];
    $self->normalize($forms_rf);
    
    # Run the tagger
    my ( $tags_rf, $lemmas_rf ) = $self->tagger->tag_sentence($forms_rf);

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
            $a_node->set_lemma( shift @$lemmas_rf );
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

  # in scenario 
  W2A::Tag module=Treex::Tool::Tagger::NameOfMyTagger
  
  # from command line 
  echo "Hello there" | treex -t \
   W2A::Tag module=Treex::Tool::Tagger::Simple::XY lemmatize=1 \
   Util::Eval anode='say $.form . "/" . $.tag . "/" . $.lemma'

=head1 COPYRIGHT AND LICENCE

Copyright 2011-2012 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

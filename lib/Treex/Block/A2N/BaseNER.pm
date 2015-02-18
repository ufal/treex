package Treex::Block::A2N::BaseNER;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has model => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has ner_module => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
    documentation => 'name of the module implementing Treex::Tool::NER::Role',
);

has ner => (
    is => 'rw',
    does => 'Treex::Tool::NER::Role',
    lazy_build => 1,
    documentation => 'instance of the module implementing Treex::Tool::NER::Role',
);

has _args => (is => 'rw');


sub BUILD {
    my ($self, $arg_ref) = @_;

    # We need to store parameters of this block and pass them to the ner's constructor
    $self->_set_args($arg_ref);
    return;
}

sub _build_ner {
    my ($self) = @_;
    my $module = $self->ner_module;

    eval "use $module;1" or log_fatal "Can't use $module\n$@";
    
    $self->_args->{model} = $self->model;
    
    my $ner = $module->new($self->_args);
    #my $ner = eval "$module->new(\$self->_args);" or log_fatal "Can't load $module\n$@";
    
    return $ner;
}

sub _build_ner_module {
    log_fatal 'Parameter "ner_module" is required when using A2N::BaseNER directly in scenario. E.g. A2N::BaseNER ner_module=Treex::Tool::NER::NameTag';
}

sub process_start {
    my ($self) = @_;

    # ner is build lazily, but it can involve loading huge models,
    # so it should be done now, instead of when processing the first document.
    $self->ner;
    return;
}


sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    # skip empty sentence
    return if !@anodes;

    # Create new n-tree
    my $n_root = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    # The real work
    my $entities_rf = $self->ner->find_entities([map {$_->form} @anodes]);

    foreach my $entity (@$entities_rf) {
        my @entity_anodes = @anodes[$entity->{start} .. $entity->{end}];
                  
        my $n_node = $n_root->create_child(
            ne_type => $entity->{type},
            normalized_name => $self->guess_normalized_name(\@entity_anodes, $entity->{type}),
        );
        $n_node->set_anodes(@entity_anodes);
    }

    return;
}

sub guess_normalized_name {
    my ($self, $entity_anodes_rf, $type) = @_;
    return join ' ', map {$_->lemma // $_->form} @$entity_anodes_rf;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::BaseNER - base class for NER blocks

=head1 SYNOPSIS

  # ==== from command line (A2N::BaseNER in scenario) ====
  echo "Federal Reserve Bank of New York was led by Timothy R. Geithner in New York." | treex -t \
   A2N::BaseNER ner_module=Treex::Tool::NER::NameTag model=data/models/nametag/en/english-conll-140408.ner \
   Util::Eval nnode='say $.ne_type ."\t". $.normalized_name'

  # ==== creating a derived class ====
  package Treex::Block::A2N::XyNER;
  use Moose; use Treex::Core::Common;
  use Treex::Tool::NER::Xy;
  extends 'Treex::Block::W2A::Tag';

  # set a default model file
  has '+model' => (default => 'data/models/ner/xy/123.model');

  # and set the default NER module
  sub _build_ner {
    my ($self) = @_;
    
    # $self->_args is a hashref of all parameters passed to this block (from scenario),
    # but as the "model" is now specified by its default value, we need to add it to _args here.
    $self->_args->{model} = $self->model;
    
    # you can add more args to the constructor
    $self->_args->{mem} = '1G'; # for example
    
    return Treex::Tool::NER::Xy->new($self->_args);
  }
  1; # add POD and that's all :-)

=head1 DESCRIPTION

This class serves two purposes:

- It is a base class for all other NER (named entity recognizer) blocks.

- It can be used directly in the scenario with specifying the name of the NER perl module in the parameter C<ner_module>.


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

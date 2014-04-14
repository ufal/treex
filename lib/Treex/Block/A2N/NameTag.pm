package Treex::Block::A2N::NameTag;
use Moose;
use Treex::Core::Common;
use Treex::Tool::NER::NameTag;
extends 'Treex::Core::Block';

has model => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has tool => (
    is => 'rw',
    does => 'Treex::Tool::NER::NameTag',
    lazy_build => 1,
);

has _args => (is => 'rw');

sub BUILD {
    my ($self, $arg_ref) = @_;

    # We need to store parameters of this block and pass them to the tagger's constructor
    $self->_set_args($arg_ref);
    return;
}

sub _build_tool {
    my ($self) = @_;
    $self->_args->{model} = $self->model;
    return Treex::Tool::NER::NameTag->new($self->_args);
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
    my $entities_rf = $self->tool->find_entities([map {$_->form} @anodes]);

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

Treex::Block::A2N::NameTag

=head1 DESCRIPTION

Apply named entity recognizer NameTag
by Milan Straka and Jana Straková.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

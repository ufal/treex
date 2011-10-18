package Treex::Tool::Parser::MSTperl::Labeller;

use Moose;
use Carp;

use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Edge;
use Treex::Tool::Parser::MSTperl::Model;

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has model => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::Model]',
    is  => 'rw',
);

sub BUILD {
    my ($self) = @_;

    $self->model(
        Treex::Tool::Parser::MSTperl::Model->new(
            featuresControl => $self->config->labelledFeaturesControl
        )
    );

    return;
}

sub load_model {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    return $self->model->load($filename);
}

sub label_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    # parse sentence (does not modify $sentence)
    my $sentence_labelled = $self->label_sentence_internal($sentence);

    return $sentence_labelled->toLabelsArray();
}

sub label_sentence_internal {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    if ( !$self->model ) {
        croak "MSTperl parser error: There is no model for labelling!";
    }

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonlabelled();
    my $sentence_length       = $sentence_working_copy->len();

    # TODO

    return $sentence_working_copy;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::Lebeller - pure Perl implementation
of a lebeller for the MST parser

=head1 DESCRIPTION

This is a Perl implementation of the labeller for MST Parser described in
McDonald et al.:
#TODO

=head1 METHODS

=over 4

=item $labeller->load_model('modelfile.model');

Loads a labelled model (= sets feature weights)
using L<Treex::Tool::Parser::MSTperl::Model/load>.

A model has to be loaded before sentences can be labelled.

=item $parser->label_sentence($sentence);

Labels a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It
sets the C<label> field of each node (instance of
L<Treex::Tool::Parser::MSTperl::Node>), i.e. a word in the sentence, and also
returns these labels as an array reference.

Any labelling information already contained in the sentence gets discarded
(explicitely, by calling
L<Treex::Tool::Parser::MSTperl::Sentence/copy_nonlabelled>).

=item $parser->label_sentence_internal($sentence);

Does the actual labelling, returning a labelled instance of 
L<Treex::Tool::Parser::MSTperl::Sentence>. The C<label_sentence> sub is 
actually only a wrapper for this method which extracts the labels of the 
nodes and returns these.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

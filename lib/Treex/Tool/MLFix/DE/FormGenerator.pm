package Treex::Tool::MLFix::DE::FormGenerator;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::MLFix::FormGenerator', 'Treex::Tool::Flect::FlectBlock';

has '+model_file' => ( default => 'data/models/flect/model-de_europarl_asynth-t005-l1_10_00001.pickle.gz' );
has '+features_file' => ( default => 'data/models/flect/model-de_europarl_asynth-t005.features.yml');

# We have to build Flect ourselves since this module is used as a Treex::Tool and not a Treex::Block
sub BUILD {
    my ($self) = @_;

    my $model = Treex::Core::Resource::require_file_from_share( $self->model_file );

    my $flect = Treex::Tool::Flect::Base->new(
        {
            model_file          => $model,
            features            => $self->_features_file_data->{plain_labels},
            additional_features => $self->_features_file_data->{additional},
        }
    );
    $self->_set_flect($flect);
}

sub get_form {

    my ( $self, $node, $tag ) = @_;

    my @nodes = ();
    push @nodes, $node;
    my @forms = $self->inflect_nodes(@nodes);

    return $forms[0];
}

# changes the tag in the node and regebnerates the form correspondingly
sub regenerate_node {
    my ( $self, $node, $dont_try_switch_number, $ennode ) = @_;

    my $old_form = $node->form;
    my $new_tag = $node->tag;

    my $new_form = $self->get_form( $node, $new_tag );
    return if !defined $new_form;
    
    $new_form = ucfirst $new_form if $old_form =~ /^(\p{isUpper})/;
    $new_form = uc $new_form      if $old_form =~ /^(\p{isUpper}*)$/;
    $node->set_form($new_form);

    return $new_form;
}

1;

=head1 NAME 

Treex::Tool::MLFix::DE::FormGenerator

=head1 DESCRIPTION

This package provides the L<get_form> method,
which tries to generate the wordform
corresponding to the given lemma and tag.

=head1 METHODS

=over

=item my $form = $formGenerator->get_form($lemma, $tag)

Returns the form corresponding to the given lemma and tag, 
or C<undef> if no form can be generated.
In such case, it also issues the following warning:
"Can't find a word for lemma '$lemma' and tag '$tag'."

=back

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

package Treex::Block::MLFix::DE::ScikitLearn;

use Moose;
use utf8;
use Treex::Core::Common;
use Lingua::Interset;

use Treex::Tool::MLFix::DE::FormGenerator;

extends 'Treex::Block::MLFix::ScikitLearn';

sub _build_form_generator {
	my ($self) = @_;

	return Treex::Tool::MLFix::DE::FormGenerator->new();
}

sub _predict_new_tags {
    my ($self, $node, $predictions) = @_;
    my %tags = ();

    foreach my $model_name (keys %{ $self->_models }) {
        foreach my $prediction (keys %{ $predictions->{$model_name} }) {
            my $iset_hash = $node->get_iset_structure();
            my $old_iset_hash = $iset_hash;
            my @targets = @{ $self->config->{predict} };
            @$iset_hash{ map { s/new_node_//; $_; } @targets } = split /;/, $prediction;
            #log_info($node->get_iset_values);

            # We do not encode a new tag because Flect expects concatenated Iset values
            $node->set_iset($iset_hash);
            my $tag = join "+", $node->get_iset_values();
            log_info($tag);
            $node->set_iset($old_iset_hash);

            $self->chosen_model->{$node->id . " $tag"} = $model_name
                if !defined $tags{$tag} ||
                    $predictions->{$model_name}->{$prediction} > $tags{$tag};
            $tags{$tag} = $predictions->{$model_name}->{$prediction}
                if !defined $tags{$tag} ||
                    $predictions->{$model_name}->{$prediction} > $tags{$tag};
        }
    }
    return \%tags;
}

1;

=head1 NAME

MLFix::CS::ScikitLearn

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

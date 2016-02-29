package Treex::Block::MLFix::ScikitLearn;
use Moose;
use Treex::Core::Common;
use utf8;
use Lingua::Interset 2.050 qw(encode);

use Treex::Tool::MLFix::ScikitLearn;

extends 'Treex::Block::MLFix::MLFix';

sub _load_models {
    my ($self) = @_;

	my $models_rf = $self->config->{models};
	log_fatal("No models listed in the configuration file") if !(%$models_rf);

	my %models = ();
	foreach my $model_name (keys %$models_rf) {
		my $model = Treex::Tool::MLFix::ScikitLearn->new(
			config_file => $self->config_file,
			model_file => $models_rf->{$model_name}
		);
		$models{$model_name} = $model;
	}

    return \%models;
}

sub _predict_new_tags {
	my ($self, $predictions) = @_;
	my %tags = ();

	foreach my $model_name (keys %{ $self->_models }) {
		foreach my $prediction (keys %{ $predictions->{$model_name} }) {
			my %iset_hash = ();
			@iset_hash{ map { s/new_node_//; $_; } @{ $self->config->{predict} } } = split /;/, $prediction;

			my $fs = Lingua::Interset::FeatureStructure->new();
			$fs->set_hash(\%iset_hash);

			my $tag = encode( $self->iset_driver, $fs);
			$tags{$tag} = $predictions->{$model_name}->{$prediction} 
				if !defined $tags{$tag} ||
					$predictions->{$model_name}->{$prediction} > $tags{$tag};
		}
	}
	return \%tags;
}

1;

=head1 NAME 

Treex::Block::MLFix::ScikitLearn -- base class using ScikitLearn-only MLFix models

=head1 DESCRIPTION

#TODO

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


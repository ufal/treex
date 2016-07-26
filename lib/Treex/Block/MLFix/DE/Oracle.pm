package Treex::Block::MLFix::DE::Oracle;

use Moose;
use utf8;
use Treex::Core::Common;
use Lingua::Interset;

use Treex::Tool::MLFix::DE::FormGenerator;

extends 'Treex::Block::MLFix::Oracle';

sub _build_form_generator {
	my ($self) = @_;

	return Treex::Tool::MLFix::DE::FormGenerator->new();
}

sub _predict_new_tags {
    my ($self, $node, $predictions) = @_;
    my %tags = ();

    my $model_name = "Oracle";
    foreach my $prediction (keys %{ $predictions->{$model_name} }) {
        my $iset_hash = $node->get_iset_structure();
        use Data::Dumper;
        log_info("Dump Iset Old:");
        log_info(Dumper($iset_hash));

#        my @pred_values = split /;/, $prediction;
#        my $iterator = List::MoreUtils::each_arrayref($self->config->{predict}, \@pred_values);
#        while ( my ($key, $value) = $iterator->() ) {
#            $key =~ s/new_node_//;
#            $iset_hash->{ $key } = $value;
#        }

        my @targets = @{ $self->config->{predict} };
        @$iset_hash{ map { s/new_node_//; $_; } @targets } = split /;/, $prediction;
        log_info("Dump Iset New:");
        log_info(Dumper($iset_hash));
#        foreach my $key (keys %$iset_hash) {
#            delete $iset_hash->{$key} if !defined $iset_hash->{$key} || $iset_hash->{$key} eq "";
#        }

        $node->set_iset($iset_hash);

        my $tag = join "+", $node->get_iset_values();
        log_info($tag);

        $tags{$tag} = $predictions->{$model_name}->{$prediction};
        $self->chosen_model->{$node->id . " $tag"} = $model_name;
    }

    return \%tags;
}

1;

=head1 NAME

MLFix::DE::Oracle

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

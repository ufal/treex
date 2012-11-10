package Treex::Block::T2T::CS2CS::FixInfrequentNouns;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::FixInfrequentFormemes';

# decide whether to change the formeme,
# based on the scores and the thresholds
sub decide_on_change {
    my ( $self, $node_info ) = @_;

    my $m = $self->magic;

    # fix only Ns with no or one aux node
    # (to be tuned and eventually made more efficient)
    # TODO: this should be also respected in the model!
    if (
	($node_info->{'syntpos'} eq 'n' || $m =~ /a/) # fix only syntactical nouns
	&& (@{ $node_info->{'preps'} } <= 1 || $m =~ /m/) # do not fix multiword prepositions
	&& ( $node_info->{'ptlemma'} ne 'být' || $m !~ /b/) # do not fix if parent is "být"
	&& ( # adding or removing nodes
	     (@{ $node_info->{'preps'} } == @{ $node_info->{'bpreps'} }) # keep number of preps
	     || ($m =~ /r/) # add/remove
	     || (@{ $node_info->{'preps'} } < @{ $node_info->{'bpreps'} } && $m =~ /\+/) # add
	     || (@{ $node_info->{'preps'} } > @{ $node_info->{'bpreps'} } && $m =~ /-/) # remove
	)
	&& ($node_info->{'mpos'} ne 'P' || $m =~ /p/) # do not fix morphological pronouns
	) {
	if ($m =~ /e/ && $node_info->{'enformeme'}) {
	    $node_info->{'change'} = (
		( $node_info->{'original_score'} < $self->lower_threshold_en )
		&&
		( $node_info->{'best_score'} > $self->upper_threshold_en )
		);
	}
	else {
	    $node_info->{'change'} = (
		( $node_info->{'original_score'} < $self->lower_threshold )
		&&
		( $node_info->{'best_score'} > $self->upper_threshold )
		);
	}
    }
    else {
        $node_info->{'change'} = 0;
    }

    return $node_info->{'change'};
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::FixInfrequentNouns -
An attempt to replace infrequent formemes by some more frequent ones.
(A Deepfix block.)

=head1 DESCRIPTION

An attempt to replace infrequent formemes by some more frequent ones.

Each node's formeme is checked against certain conditions --
currently, we attempt to fix only formemes of syntactical nouns
that are not morphological pronouns and that have no or one preposition.
Each such formeme is scored against the C<model> -- currently this is
a +1 smoothed MLE on CzEng data; the node's formeme is conditioned by
the t-lemma of the node and the t-lemma of its effective parent.
If the score of the current formeme is below C<lower_threshold>
and the score of the best scoring alternative formeme
is above C<upper_threshold>, the change is performed.

=head1 PARAMETERS

=over

=item C<lower_threshold>

Only formemes with a score below C<lower_threshold> are fixed.
Default is 0.2.

=item C<upper_threshold>

Formemes are only changed to formemes with a score above C<upper_threshold>.
Default is 0.85.

=item C<model>

Absolute path to the model file.
Can be overridden by C<model_from_share>.

=item C<model_from_share>

Path to the model file, relative to C<share/data/models/deepfix/>.
The model file is automatically downloaded if missing locally but available online.
Overrides C<model>.
Default is undef.

=item C<orig_alignment_type>

Type of alignment between the CS t-trees.
Default is C<orig>.
The alignment must lead from this zone to the other zone.

=item C<src_alignment_type>

Type of alignment between the cs_Tfix t-tree and the en t-tree.
Default is C<src>.
The alignemt must lead from cs_Tfix to en.

=item C<log_to_console>

Set to C<1> to log details about the changes performed, using C<log_info()>.
Default is C<0>.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

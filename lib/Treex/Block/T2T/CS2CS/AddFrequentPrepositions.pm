package Treex::Block::T2T::CS2CS::AddFrequentPrepositions;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::FixInfrequentFormemes';

# decide whether to change the formeme,
# based on the scores and the thresholds
sub decide_on_change {
    my ( $self, $node ) = @_;

    my $change = -1;
    my $m      = $self->magic;

    if (

        # fix only syntactical nouns
        (
               $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} eq 'n'
            || $m =~ /a/
        )

        # do not fix morphological pronouns
        && ( $node->wild->{'deepfix_info'}->{'mpos'} ne 'P' || $m =~ /p/ )

        # originally without prepositions
        && ( $node->wild->{'deepfix_info'}->{'formeme'}->{'prep'} eq '' )

        # now with preposition(s)
        && ( $node->wild->{'deepfix_info'}->{'best_formeme'}->{'prep'} ne '' )

        # do not fix if parent is "být"
        && ( $node->wild->{'deepfix_info'}->{'ptlemma'} ne 'být' || $m !~ /b/ )

        # do not fix if there are numerals around
        # because they behave in a speacial way
        && ( !$self->numerals_are_around($node) )
      )
    {
        $change = $self->decide_on_change_en_model($node);

        if ( $change == 1 ) {

            # seems good, but let's ensure
            # that there won't be two adjacent preps in the sentence
            # since this is very uncommon

            my $lexnode = $node->wild->{'deepfix_info'}->{'lexnode'};
            if ( defined $lexnode ) {
                my @should_not_be_prep = ();

                my $prev_node = $lexnode->get_prev_node();
                if ( defined $prev_node ) {
                    push @should_not_be_prep, $prev_node;
                }

                # the prep will be placed to the left of this node
                my $leftmost_desc = $lexnode->get_descendants(
                    {
                        preceding_only => 1,
                        first_only     => 1,
                    }
                );
                if ( defined $leftmost_desc ) {
                    push @should_not_be_prep, $leftmost_desc;

                    # the prep will be placed to the right of this node
                    my $lmd_prev_node = $leftmost_desc->get_prev_node();
                    if ( defined $lmd_prev_node ) {
                        push @should_not_be_prep, $lmd_prev_node;
                    }
                }

                if (
                    any {
                        $self->get_node_tag_cat( $_, 'POS' ) eq 'R'
                          || $_->lemma eq
                          $node->wild->{'deepfix_info'}->{'best_formeme'}
                          ->{'prep'};
                    }
                    @should_not_be_prep
                  )
                {
                    $change = -1;
                }
            }

        }

    }
    else {
        $change = -1;
    }

    return $change;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::AddFrequentPrepositions -
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

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

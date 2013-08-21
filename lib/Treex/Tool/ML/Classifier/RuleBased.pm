package Treex::Tool::ML::Classifier::RuleBased;

use Moose;
use List::MoreUtils qw/all any/;

with 'Treex::Tool::ML::Classifier';

sub score {
    my ($self, $instance, $class) = @_;
    # supports just disjunction so far

    my $pred_class = (any {$instance->{$_}} (keys %{$instance})) ? 1 : 0;
    return ($class == $pred_class);
}

sub all_classes {
    return (0, 1);
}

# TODO this shouldn't be here
sub log_feat_weights {
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Classifier::RuleBased

=head1 DESCRIPTION

A wrapper for a rule-based classifier.
For the time being, it supports just disjunction of all features.

=head1 METHODS

=over

=item score

It assignes a score (or probability) to the given instance being
labeled with the given class.

=item all_classes

It returns all possible classes.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

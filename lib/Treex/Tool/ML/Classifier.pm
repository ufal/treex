package Treex::Tool::ML::Classifier;

use Moose::Role;

requires 'score';
requires 'all_classes';

requires 'log_feat_weights';

sub predict {
    my ($self, $instance) = @_;

    my %probs_for_y = map {$_ => $self->score($instance, $_)} $self->all_classes;
    my ($best_class) = sort {$probs_for_y{$b} <=> $probs_for_y{$a} || $a cmp $b} keys %probs_for_y;
    return $best_class;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Classifier

=head1 DESCRIPTION

A role for classifiers. Every ML method (but it fits rule-based methods, too) 
which is a classifier should implement this role.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item score

It assignes a score (or probability) to the given instance being
labeled with the given class.

=item all_classes

It returns all possible classes.

=back

=head2 Already implemented

=over

=item C<predict>

It picks the class with the greatest score, given an instance.
The methods C<score> and C<all_classes> are called inside this method.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

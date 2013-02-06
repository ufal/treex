package Treex::Tool::ML::Learner;

use Moose::Role;

requires 'see';
requires 'learn';
requires 'cut_features';
requires 'forget_all';

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Learner

=head1 DESCRIPTION

A role for machine learning class. 

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item see

Show an instance ($x, $y) to the learner. $x constists of features
and $y is a true label.

=item learn

Learn a model based on the instances it has been shown.

=item cut_features

Cut features to simplify the resulting model.

=item forget_all

Reinitialize the learner. Ready for training a new model.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

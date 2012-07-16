package Treex::Tool::Coreference::ContentWordFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::NodeFilter';

# content word filtering
sub is_candidate {
    my ($self, $tnode) = @_;

    my $starts_with_hash = ($tnode->t_lemma =~ /^#/);
    my $is_gener = $tnode->is_generated;
    
    return (!$starts_with_hash && !$is_gener);
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::ContentWordFilter

=head1 DESCRIPTION

A filter for nodes that are content words.

=head1 METHODS

=item is_candidate

Returns whether the input node is a content word or not.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

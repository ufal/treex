package Treex::Tool::Coreference::NodeFilter::Verb;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter::Utils qw/ternary_arg/;

sub is_sem_verb {
    my ($tnode, $args) = @_;
    return (defined $tnode->gram_sempos && ($tnode->gram_sempos =~ /^v/));
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::NodeFilter::Verb

=head1 DESCRIPTION

A filter for nodes that are semantic verbs.

=head1 METHODS

=over

=item my $bool = is_sem_verb($tnode, $args)

Returns whether the input C<$tnode> is a semantic verb or not.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


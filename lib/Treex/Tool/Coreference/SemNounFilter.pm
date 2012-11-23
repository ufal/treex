package Treex::Tool::Coreference::SemNounFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::NodeFilter';

# semantic noun filtering
sub is_candidate {
    my ($self, $node) = @_;
    my $anode = $node->get_lex_anode;
    
    my $is_sem_noun = defined $node->gram_sempos && ($node->gram_sempos =~ /^n/);
    my $not_first_second_pers = !$node->gram_person || ($node->gram_person !~ /1|2/);
    # if the node is not generated, leave just nouns, pronouns, adjectives and foreign words
    my $not_certain_pos = !$anode || ($anode->tag !~ /^[CJRTDIZV]/);
#     debug
#     if ($is_sem_noun && $not_first_second_pers && $not_certain_pos) {
#         if ( $node->functor eq "CONJ" ) {
#             print STDERR "nojono\n";
#         }
#     }

    return ($is_sem_noun && $not_first_second_pers && $not_certain_pos);
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::SemNounFilter

=head1 DESCRIPTION

A filter for nodes that are semantic nouns.

=head1 METHODS

=item is_candidate

Returns whether the input node is a semantic noun or not.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

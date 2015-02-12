package Treex::Block::A2T::CS::FixNonthirdPersSubj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ($t_node->is_clause_head
        && grep { $_->tag =~ /^.......[12]/ } $t_node->get_anodes()
    ) {
        my @actors = grep {
            ( ($_->functor || "" ) eq "ACT" )
            || ( ( $_->formeme || "" ) eq "n:1" )
            } $t_node->get_echildren( { or_topological => 1 } );
        return if @actors == 0;
        foreach my $actor (@actors) {
            if ($actor->t_lemma ne '#PersPron') {
                if ($actor->functor eq 'ACT') {
                    $actor->set_functor('PAT');
                }
                if ($actor->formeme eq 'n:1') {
                    $actor->set_formeme('n:4');
                }
            }
        }
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::FixNonthirdPersSubj

=head1 DESCRIPTION

If the verb is in 1st or 2nd person, the subject must be a personal pronoun.
Thus, if it is not, it is not the subject, and we therefore change its labelling:
if it was ACT, it becomes PAT, and if it was n:1, it becomes n:4.

(Quite a hacky block, also probably this should be done already at a-layer or even m-layer...)

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

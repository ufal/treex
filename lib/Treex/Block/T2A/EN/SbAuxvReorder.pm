package Treex::Block::T2A::EN::SbAuxvReorder;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # finite inter clause head
    if ( !$tnode->is_coap_root
        && $tnode->formeme =~ /v:*.fin/
        && ($tnode->sentmod // '') eq 'inter'
    ) {

        my @subjects =
            map { $_->get_lex_anode() }
            grep { ($_->t_lemma // '') !~ /^wh(at|ich|om?|ere|en|y)|how$/ }
            _grep_formeme( 'n:subj', $tnode->get_children({ ordered => 1 }) );
        my ($first_anode) = $tnode->get_anodes();

        # shift subjects after first anode
        foreach my $subject ( reverse @subjects ) {
            $subject->shift_after_node($first_anode);
        }
    
    }

    return;
}

# grep a list of nodes for a given formeme regexp, abstract away from coordinations
sub _grep_formeme {

    my ( $formeme, @nodes ) = @_;

    return grep {
        $_->formeme =~ /^$formeme$/
            or
            ( $_->is_coap_root and any { $_->formeme =~ /^$formeme$/ } $_->get_echildren( { or_topological => 1 } ) )
    } @nodes;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::SbAuxvReorder

=head1 DESCRIPTION

Put subject as the second node in compund verb constructions for interrogative sentences.

Assumes that anodes of the verb contain only verbs,
has thus to be called after AddAuxVerb* blocks,
but before AddVerbNegation block.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

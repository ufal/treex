package Treex::Block::A2T::MinimizeGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'if_loss' => (
    is            => 'ro',
    isa           => enum( [qw(fill delete ignore)] ),
    default       => 'fill',
    documentation => 'What to do if the deleted information would be lost: fill (fill the grammatemes to the noun, the default), delete, ignore',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $sempos = $tnode->gram_sempos || '';
    
    if ($sempos =~ /^v/){
        my $noun = $self->find_subject($tnode);
        $self->solve_grammatemes($tnode, $noun, qw(gender number person));
    }

    elsif ($sempos =~ /^adj/){
        my $noun = $self->find_governing_noun($tnode);
        $self->solve_grammatemes($tnode, $noun, qw(gender number definiteness));
    }

    return;
}

sub solve_grammatemes {
    my ($self, $node, $noun, @grammatemes) = @_;
    foreach my $grammateme (@grammatemes){

        # If "delete" was required, then unconditionally delete.
        if ($self->if_loss eq 'delete') {
            $node->set_attr("gram/$grammateme", undef);
            next;
        }

        # If the $noun could not be found, we are finished.
        next if !$noun;
        
        # Otherwise check if there is a disagreement between the $noun and $node.
        my $node_gram = $node->get_attr("gram/$grammateme") or next;
        my $noun_gram = $noun->get_attr("gram/$grammateme");
        if (!$noun_gram){
            if (($noun->formeme||'') =~ /^n/){
                # Fill the missing grammateme of the noun
                # except for 3rd person (which is implied).
                if ($self->if_loss eq 'fill' && $node_gram ne '3'){
                    $noun->set_attr("gram/$grammateme", $node_gram);
                }
                $node->set_attr("gram/$grammateme", undef);
            } else {
                # TODO What to do if the $noun is not actually a noun?
                # Safest option here seems to be "ignore" (even if if_loss eq "fill").
            }
        }
        elsif ($node_gram eq $noun_gram){
            $node->set_attr("gram/$grammateme", undef);
        } else {
            # TODO What to do if the grammatemes are different?
            # Check coordinations, e.g. "Bob(singular) and Jim(singular) go(plural)."
        }
    }
    return;
}

sub find_subject {
    my ($self, $verb) = @_;
    my @subjects = grep {my $an = $_->get_lex_anode; $an && $an->afun eq 'Sb'} $verb->get_echildren();

    # In pro-drop languages, there may be a generated node as the Actor
    if (!@subjects){
        @subjects = grep {($_->functor||'') eq 'ACT'} $verb->get_echildren();
    }
    return if !@subjects;

    #TODO: if (@subjects > 1){select the subject with best Interset features}
    return $subjects[0];
}

sub find_governing_noun {
    my ($self, $t_adj) = @_;
    my $a_adj = $t_adj->get_lex_anode();
    if ($a_adj && $a_adj->afun eq 'Pnom'){
        my ($t_verb) = $t_adj->get_eparents() or return;
        return $self->find_subject($t_verb);
    }
    my @eparents = $t_adj->get_eparents();
    return if !@eparents;
    return $eparents[0];
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::MinimizeGrammatemes - delete gender, number and person from verbs and adj

=head1 DESCRIPTION

Grammatemes should not be redundant (similarly to all other attributes on the  t-layer).
One option is to fill only the needed (non-redundant) grammatemes in the first place.
The second option is to use C<T2A::SetGrammatemes> (which fills grammatems for the corresponding morphosyntactic Interset features)
and the use this block to delete the redundant grammatemes.
Ideally, we would like:

 nouns: gender, number, definiteness, negation (+person for pronouns)
 adjectives+adverbs: degcmp, negation
 verbs: any except gender, number, person, degcmp, definiteness

Therefore this block deletes C<gender>, C<number>, C<person> and C<definiteness> from semantic verbs and adjectives.

TODO: what about nouns in attributive position which are congruent with their governing noun?

=head1 PARAMETERS

=head2 if_loss

What to do if the deleted information would be lost?
Verbs should get gender, number and person from the subject.
Default value of person is 3.
Adjectives should get it from their governing noun
or from the verb subject in case of copula constructions.
If the info is missing at the node (called "noun node")
where we expect it (or the node itself is missing), we can:

=over

=item fill

Fill the missing info to the noun node
and delete it from the verb/adjective.
If the noun node cannot

=item delete

Delete the info from the verb/adjective
without trying to preserve it in the noun node.

=item ignore

Don't delete the info if it would lead to a loss of info.

=cut


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

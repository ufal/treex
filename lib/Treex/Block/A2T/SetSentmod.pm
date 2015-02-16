package Treex::Block::A2T::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;
    my @to_process = grep { $_->is_clause_head } $t_root->get_descendants();
    if ( !@to_process ) {
        push @to_process, ( $t_root->get_children( { first_only => 1 } ) );
    }
    foreach my $t_clause (@to_process) {

        # Default is the normal indicative mood
        my $sentmod = 'enunc';

        my $a_clause = $t_clause->get_lex_anode();
        if ($a_clause) {

            # Questions
            if ( $self->is_question( $t_clause, $a_clause ) ) {
                $sentmod = 'inter';
            }

            # Imperatives
            elsif ( $self->is_imperative( $t_clause, $a_clause ) ) {
                $sentmod = 'imper';
            }
        }
        $t_clause->set_sentmod($sentmod);
    }
    return;
}

# Example implementation: using "?" at the end of the sentence to detect the question
# Only works for the last topmost clause
sub is_question {
    my ( $self, $t_node, $a_node ) = @_;
    my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } );
    return 0 if ( !$t_parent->is_root );
    return 0 if any { $_->is_clause_head and $t_node->precedes($_) } $t_parent->get_echildren();

    my $a_root = $t_parent->get_zone->get_atree();
    return 0 if ( !$a_root );

    my ( $last_token, @toks ) = reverse $a_root->get_descendants( { ordered => 1 } );
    if ( @toks && $last_token->afun eq 'AuxG' ) {
        $last_token = shift @toks;
    }
    if ( $last_token && $last_token->form eq '?' ) {
        return 1;
    }
    return 0;
}

# Example implementation: works for Czech and English
sub is_imperative {
    my ( $self, $t_node, $a_node ) = @_;

    # For PDT-like tagset
    return 1 if $a_node->tag =~ /^Vi/;

    # For English:  imperative is an infinitive verb (VB) with no left children
    return 1 if $a_node->tag eq 'VB' && !$a_node->get_children( { preceding_only => 1 } );

    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetSentmod - fill sentence modality (question, imperative)

=head1 DESCRIPTION

T-layer sentmod attribute is filled based in all clause heads, based on 
the main verb of the clause and and the last punctuation token (for questions).

Override the is_imperative and is_question methods for language-specific behavior.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

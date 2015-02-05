package Treex::Block::A2T::NL::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetSentmod';

override 'is_question' => sub {
    my ( $self, $aroot ) = @_;

    # The default detection using the question mark is accepted, but we go on to detect questions without it
    return 1 if super();

    my $anode = $aroot->get_children( { first_only => 1 } );

    # Detecting WH-questions: 1 left child which contains a wh-word
    # and Y/N questions: no left children, but a subject to the right
    if ( $anode->match_iset( 'pos' => 'verb', 'verbform' => 'fin' ) ) {
        
        my @left_children = grep { not $_->is_clause_head } $anode->get_children( { preceding_only => 1 } );

        # no question can have more than 1 left child (except subordinate clauses)
        return 0 if ( @left_children > 1 );

        # if it has 1 left child, it must contain a wh-word to be a WH-question
        if ( @left_children ){
            return 1 if ( any { $_->lemma =~ /^(wie|wiens|wat|welke?|wanneer|hoeveel|hoe)$/ } $left_children[0]->get_descendants( { add_self => 1 } ) );
            return 0;
        }
                                                                                                                                                        
        # if it has no left children, it must have a subject to be a Y/N question
        return 1 if ( any { $_->afun eq 'Sb' } $anode->get_children() );
    }
    return 0;
};

override 'is_imperative' => sub {
    my ( $self, $aroot ) = @_;
    my $anode = $aroot->get_children( { first_only => 1 } );

    # Imperative is a finite verb that has no left children in the same clause and no subject
    if ( $anode->match_iset( 'pos' => 'verb', 'verbform' => 'fin' ) ) {
        return 0 if ( any { not $_->is_clause_head } $anode->get_children( { preceding_only => 1 } ) );
        return 0 if ( any { $_->afun eq 'Sb' } $anode->get_children() );
        return 1;
    }

    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::NL::SetSentmod - fill sentence modality (question, imperative)

=head1 DESCRIPTION

Dutch-specific rule to find imperatives, otherwise using L<Treex::Block::A2T::SetSentmod>.

=head1 AUTHOR

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2T::NL::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetSentmod';

override 'is_question' => sub {
    my ($self, $aroot) = @_;

    # if it has a question mark, it's a question... but we also try to detect this using syntax
    return 1 if super();

    my $anode = $aroot->get_children( { first_only => 1 } ); 
    
    # wh-questions: 1 left child which contains a wh-word
    # Y/N questions: no left children, but a subject to the right
    if ( $anode->match_iset('pos' => 'verb', 'verbform' => 'fin') ){
        my @left_children = grep { not $_->is_clause_head } $anode->get_children( { preceding_only => 1 } );
        # no question can have more than 1 left child
        return 0 if (@left_children > 1);
        # the 1st child is/contains a wh-word, so it is a wh-question
        return 1 if (any { $_->lemma =~ /^(wie|wiens|wat|welke?|wanneer|hoeveel|hoe)$/ } $left_children[0]->get_descendants({add_self=>1}));
        # if it's not a wh-question, it must not have left children
        return 0 if (@left_children);
        # but it must have a subject
        return 1 if (any { $_->afun eq 'Sb' } $anode->get_children());
    }
    return 0;
};

override 'is_imperative' => sub {
    my ($self, $aroot) = @_;
    my $anode = $aroot->get_children( { first_only => 1 } ); 
    
    # imperative is a finite verb
    # that has no left children in the same clause and no subject
    if ( $anode->match_iset('pos' => 'verb', 'verbform' => 'fin') ){
        return 0 if (any { not $_->is_clause_head } $anode->get_children( { preceding_only => 1 } ));
        return 0 if (any { $_->afun eq 'Sb' } $anode->get_children());
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

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

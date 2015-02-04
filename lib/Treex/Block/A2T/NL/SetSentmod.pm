package Treex::Block::A2T::NL::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetSentmod';


override 'is_imperative' => sub {
    my ($self, $anode) = @_;
    
    # imperative is a finite verb
    # that has no left children in the same clause and no subject
    if ( $anode->match_iset('pos' => 'verb', 'verbform' => 'fin') ){
        return 0 if (grep { not $_->is_clause_head } $anode->get_children( { preceding_only => 1 } ));
        return 0 if (grep { $_->afun eq 'Sb' } $anode->get_children());
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

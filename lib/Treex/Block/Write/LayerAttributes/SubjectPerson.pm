package Treex::Block::Write::LayerAttributes::SubjectPerson;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

sub modify_single {

    my ( $self, $tnode ) = @_;

    return '-' if ( ( $tnode->gram_sempos || '' ) ne 'v' );

    my $lex = $tnode->get_lex_anode();

    return '-' if ( !$lex );

    # if the person is already filled in, just return the value and don't look for subjects
    my $person = $lex->get_attr('morphcat/person');
    return $person if ( $person && $person ne '.' ); 

    # find the marked subject
    my $subject = first { ( $_->afun || '' ) eq 'Sb' } $lex->get_echildren( { or_topological => 1 } );

    # no person if no subject found
    return 'none' if ( !$subject );

    # default to third person (all except #PersPron)
    $person = $subject->get_attr('morphcat/person');
    return '3' if ( !$person || $person eq '.' );    
    return $person;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::SubjectPerson

=head1 DESCRIPTION

For verbal t-nodes, this finds the node's subject (e-child on the a-layer marked as 'Sb') and returns 
its person ('-' for non-verbal t-nodes, 'none' for no subject, '3' for subjects without morphcat/person marks).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

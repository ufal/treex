package Treex::Block::T2A::NL::Alpino::FixCompoundNouns;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';
with 'Treex::Block::T2A::NL::Alpino::MWUs';

sub process_anode {
    my ( $self, $anode ) = @_;
    return if ( !$anode->is_noun or $anode->n_node );

    my $compound_children = $self->find_compound_children($anode);
    return if ( @$compound_children <= 1 );
    
    $self->create_mwu(@$compound_children);
}

sub find_compound_children {
    my ( $self, $anode ) = @_;

    my @to_process = ($anode);
    my @found      = ();

    while (@to_process) {
        my $acur = shift @to_process;
        next if ( $acur->n_node or ( $acur->wild->{adt_term_rel} // '' ) eq 'mwp' );
        my ($tcur) = $acur->get_referencing_nodes('a/lex.rf');
        next if ( !$tcur or ( $acur != $anode and ( $tcur->formeme ne 'n:attr' or $acur->ord > $acur->get_parent()->ord ) ) );
        push @found, $acur;
        push @to_process, $acur->get_children();
    }
    return \@found;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixCompoundNouns

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

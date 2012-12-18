package Treex::Block::A2A::SetClauseDepth;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    my $n = $anode;
    my %seen;
    while (!$n->is_root){
        $seen{$n->clause_number}++ if $n->clause_number;
        $n = $n->get_parent();
    }
    $anode->wild->{clause_depth} = scalar keys %seen;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::SetClauseDepth

=head1 DESCRIPTION


=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

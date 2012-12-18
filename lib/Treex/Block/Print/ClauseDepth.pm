package Treex::Block::Print::ClauseDepth;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @d=$atree->get_descendants({ordered=>1});
    my $last_d = -1;
    for my $n (@d){
        next if !$n->clause_number;
        my $depth = $n->wild->{clause_depth};
        next if $depth == $last_d;
        print { $self->_file_handle } $depth;
        $last_d = $depth;
    }
    say { $self->_file_handle } "\t", $atree->get_address, "\t", join ' ', map {$_->form} @d;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::SetClauseDepth

=head1 DESCRIPTION


=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

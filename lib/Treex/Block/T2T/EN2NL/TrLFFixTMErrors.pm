package Treex::Block::T2T::EN2NL::TrLFFixTMErrors;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $src_t_node = $t_node->src_tnode or return;

    if ( $t_node->formeme eq 'v:fin' and $src_t_node->formeme eq 'v:rc' and not $t_node->get_parent->is_root ){
        $t_node->set_formeme('v:rc');
        $t_node->set_formeme_origin('rule-TrLFFixTMErrors');
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2NL::TrLFFixTMErrors

=head1 DESCRIPTION

Fix blatant TM errors.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


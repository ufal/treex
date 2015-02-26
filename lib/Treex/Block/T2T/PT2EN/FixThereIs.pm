package Treex::Block::T2T::PT2EN::FixThereIs;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
	my ( $self, $t_node ) = @_;

    my $src_t_node = $t_node->src_tnode;

    if ($src_t_node and $src_t_node->t_lemma eq "haver") {
        $t_node->set_t_lemma('be');
        $t_node->wild->{there_is} = 1;
            # TODO: make sure it is a verb node
    }
    

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::PT2EN::FixThereIs

=head1 DESCRIPTION

Fix the 'there is/are'

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


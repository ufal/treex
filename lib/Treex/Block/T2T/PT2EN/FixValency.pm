package Treex::Block::T2T::PT2EN::FixValency;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

my %PT2EN_FORMEME = (
    "clicar n:em+X" => "n:on+X",
);

sub process_tnode {
	my ( $self, $t_node ) = @_;

    my $src_tnode = $t_node->src_tnode;

    if ($src_tnode) {

        my $src_parent = $src_tnode->get_parent;

        my $key = $src_parent->t_lemma." ".$src_tnode->formeme;

        if ($PT2EN_FORMEME{$key}) {
            $t_node->set_formeme($PT2EN_FORMEME{$key});
        }
        # TODO: make sure it is a verb node
    }
    

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::PT2EN::FixValency

=head1 DESCRIPTION

Fix the click on valency

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.




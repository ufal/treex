package Treex::Block::T2T::EN2PT::FixThereIs;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
	my ( $self, $t_node ) = @_;

    my $src_t_node = $t_node->src_tnode;

    if ($src_t_node and $src_t_node->t_lemma eq "be" and grep {$_->lemma eq "there"} $src_t_node->get_aux_anodes) {
   
            $t_node->set_t_lemma('haver');
            my $new_node = $t_node->create_child(
                {   't_lemma'         => '#PersPron',
                    'form'          => '',
                    'functor'       => 'ACT',
                    'gram/number'   => 'sg',
                    'gram/person'   => '3',
                    'gram/sempos'        => 'n.pron.def.pers',
                    'clause_number' => '1',
                    'formeme'       => 'n:subj',
                    'is_generated'  => '1',
                    'nodetype'      => 'complex'
                }
            );
            $new_node->shift_before_subtree($t_node);
        }
    

}

1;

__END__
=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::FixThereIs

=head1 DESCRIPTION

Creates a PersPron node for the 'there is/are' 

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.





package Treex::Block::A2T::EN::FixRelClauseNoRelPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'add_cor' => ( is => 'ro', isa => 'Bool', default => 0 );

sub process_tnode {
    my ( $self, $t_node ) = @_;
        
    if (($t_node->formeme || '' ) =~ /v:fin/ 
        && $t_node->parent->precedes($t_node)
        && ( $t_node->get_parent->formeme || '' ) =~ /^n/
        && $t_node->is_clause_head
        && _clause_starts_with_subject($t_node)) {
        #_debug_print($t_node, "VFIN " . $t_node->t_lemma . ", " . $t_node->parent->t_lemma);
    
    
        $t_node->set_is_relclause_head(1);

        if ($self->add_cor) {
            my $cor = $t_node->create_child(
                {
                    is_generated => 1,
                    t_lemma      => '#Cor',
                    functor      => 'PAT',
                    formeme      => 'n:elided',
                    nodetype     => 'qcomplex',
                }
            );
            $cor->shift_after_node($t_node);
            $cor->set_clause_number($t_node);
            my $antec = $t_node->get_parent;
            if ($antec) {
                $cor->set_deref_attr( 'coref_gram.rf', [$antec] );
            }
            #print STDERR "ADDING #COR PAT: " . $cor->get_address . "\n";
            #print STDERR "ADDING SENT: " . $cor->get_zone->sentence . "\n";
        }
        # TODO: remove this
        else {
            $t_node->set_formeme('v:rc');
            $t_node->wild->{rc_no_relpron} = 1;

        }

    }
}

sub _clause_starts_with_subject {
    my ($t_verb) = @_;

    # the first node of the rlative clause must be a subject
    my ($first_node) = $t_verb->get_clause_nodes;
    if ($first_node->formeme !~ /^n:sub/) {
        return 0;
    }
    
    my $a_subject = $first_node->get_lex_anode;
    my $a_parent = $t_verb->get_parent->get_lex_anode;
    if (!defined $a_parent || !defined $a_subject) {
        return 0;
    }
    if ($a_subject->precedes($a_parent)) {
        return 0;
    }
    my @a_in_betw = grep {$_->precedes($a_subject) && $a_parent->precedes($_) } 
        $a_subject->get_root->get_descendants;
    # no punctuation mark can appear between subject of the relative clause
    # and the parent of this clause
    my @punct_in_betw = grep {$_->afun =~ /^Aux[GX]$/} @a_in_betw;

    return (@punct_in_betw == 0);
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::FixRelClauseNoRelPron

=head1 DESCRIPTION

This block marks a relative clause in cases when relative
pronoun is missing, e.g. "the man I saw".  

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

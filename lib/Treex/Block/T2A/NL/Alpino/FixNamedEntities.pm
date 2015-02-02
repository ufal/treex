package Treex::Block::T2A::NL::Alpino::FixNamedEntities;

use Moose;
use Treex::Core::Common;
use List::Util 'reduce';

extends 'Treex::Core::Block';

# Taken from http://www.perlmonks.org/?node_id=1070950
sub minindex {
    my @x = @_;
    reduce { $x[$a] < $x[$b] ? $a : $b } 0 .. $#_;
}

sub process_nnode {
    my ( $self, $nnode ) = @_;

    # only do this for the outermost n-nodes (assume the references are fixed)
    return if ( !$nnode->get_parent->is_root );

    # get all a-nodes and find one that will be used as the head of the NE structure
    my @anodes = $nnode->get_anodes();
    return if ( @anodes <= 1 );

    my $atop = $anodes[ minindex map { $_->get_depth() } @anodes ];
    my $aparent = $atop->get_parent();

    # create a new formal MWU head
    my $amwu_root = $aparent->create_child(
        {
            lemma         => '',
            form          => '',
            afun          => $atop->afun,
            clause_number => $atop->clause_number,
        }
    );
    $amwu_root->wild->{adt_phrase_rel} = $atop->wild->{adt_phrase_rel};
    $amwu_root->shift_after_node($atop);
    $amwu_root->wild->{is_formal_head} = 1;

    # link to the formal head from n-layer and t-layer to ensure correct ADTXML output
    $nnode->set_anodes( @anodes, $amwu_root );
    my ($tnode) = ( $atop->get_referencing_nodes('a/lex.rf'), $atop->get_referencing_nodes('a/aux.rf') );
    if ($tnode) {
        $tnode->set_lex_anode($amwu_root);
        $tnode->add_aux_anodes($atop);
    }

    # rehang all a-nodes under the formal head node and set their ADT (terminal and non-terminal) relation to "mwp"
    my $non_mwu_children = 0;

    foreach my $anode (@anodes) {
        $anode->set_parent($amwu_root);
        $anode->wild->{adt_phrase_rel} = 'mwp';
        $anode->wild->{adt_term_rel}   = 'mwp';

        # check for any children that are not part of the current MWU, rehang them under
        # the formal head node (and remember that we have found some)
        foreach my $achild ( $anode->get_children() ) {
            if ( not grep { $_ == $achild } @anodes ) {
                $non_mwu_children = 1;
                $achild->set_parent($amwu_root);
            }
        }
    }

    # if we found any children that are not part of the current MWU, hang the rest of
    # the MWU under its top node (to make one more depth level in ADTXML)
    if ($non_mwu_children) {
        foreach my $anode ( grep { $_ != $atop } @anodes ) {
            $anode->set_parent($atop);
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixNamedEntities

=head1 DESCRIPTION

Flattening multi-word named entities and pre-setting their Alpino relation 
(both C<wild-&gt;{adt_phrase_rel}> and C<wild-&gt;{adt_term_rel}>).
to "mwp".

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

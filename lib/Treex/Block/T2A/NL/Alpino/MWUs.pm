package Treex::Block::T2A::NL::Alpino::MWUs;

use Moose::Role;
use List::Util 'reduce';

# Taken from http://www.perlmonks.org/?node_id=1070950
sub minindex {
    my @x = @_;
    reduce { $x[$a] < $x[$b] ? $a : $b } 0 .. $#_;
}


sub create_mwu {
    my ( $self, @anodes ) = @_;

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

    # link to the formal head t-layer to ensure correct ADTXML output
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
        $atop->wild->{adt_phrase_rel} = 'hd';
    }
    
    # return the formal head
    return $amwu_root;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::MWUs

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

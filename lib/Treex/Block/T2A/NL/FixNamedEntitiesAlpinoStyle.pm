package Treex::Block::T2A::NL::FixNamedEntitiesAlpinoStyle;

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
    my ($self, $nnode) = @_;
    # only do this for the outermost n-nodes (assume the references are fixed)    
    return if (!$nnode->get_parent->is_root);
    
    # get all a-nodes and find one that will be used as the head of the NE structure
    my @anodes = $nnode->get_anodes();
    my $atop = $anodes[ minindex map { $_->get_depth() } @anodes ];

    # rehang all other a-nodes and their children under this head node, set their relation to "mwp"
    foreach my $anode (grep { $_ != $atop } @anodes){
        $anode->set_parent($atop);
        $anode->wild->{adt_rel} = 'mwp';
        foreach my $achild ($anode->get_children()){
            $achild->set_parent($atop);
        }        
    }
    
    # the terminal of the topmost node should also have rel="mwp" (but only the terminal
    # and only if the NE is composed of more than one node)
    if (@anodes > 1){
        $atop->wild->{adt_trel} = 'mwp';
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::FixNamedEntitiesAlpinoStyle

=head1 DESCRIPTION

Flattening multi-word named entities and pre-setting their Alpino relation (C<wild->{adt_rel}>)
to "mwp".

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
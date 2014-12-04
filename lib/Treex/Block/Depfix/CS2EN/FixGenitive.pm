package Treex::Block::Depfix::CS2EN::FixGenitive;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::Depfix::CS2EN::Fix';

sub fix {
    my ( $self, $child, $parent, $al_child, $al_parent ) = @_;

    return if !defined $al_child;
    my ($al_parent) = $al_child->get_eparents();
    #my ($al_al_parent) = $al_parent->get_aligned_nodes();

    if ($al_child->tag =~ /^N...2/
        && $al_parent->tag =~ /^N/
        && $parent->form ne 'of'
        # && $al_al_parent->precedes($child)
    ) {
        $self->logfix1($child, "add 'of'");
        my $of = $parent->create_child({ form => 'of', lemma => 'of'});
        $of->shift_after($parent);
        $child->set_parent($of);
        $self->logfix2($child);
    }
    
    return;
}


1;

=head1 NAME 

Treex::Block::Depfix::CS2EN::FixGenitive -- add 'of' if missing.

postavení firem
position companies
->
position of companies

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


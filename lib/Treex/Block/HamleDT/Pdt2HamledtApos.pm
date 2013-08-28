package Treex::Block::HamleDT::Pdt2HamledtApos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $old_head ) = @_;
    return if $old_head->afun ne 'Apos';
    my @children = $old_head->get_children({ordered=>1});
    my ($first_ap, @other_ap) = grep {$_->is_member}  @children;
    if (!$first_ap){
        log_warn 'Apposition without members at ' . $old_head->get_address();
        return;
    }
    # Usually, apposition has exactly two members.
    # However, ExD (and unannotated coordination) can result in more members
    # and the second member can be the whole following sentence (i.e. just one member in the tree).
    # We must be prepared also for such cases. Uncomment the following line to see them.
    #log_warn 'Strange apposition at ' . $old_head->get_address() if @other_ap != 1;
    
    # Rehang the first member of apposition as the new head.
    $first_ap->set_parent($old_head->get_parent());
    $first_ap->set_is_member(0);
    
    # Rehang other members of the apposition (hopefully just one) under the new head.
    foreach my $another_ap (@other_ap){
        $another_ap->set_parent($first_ap);
        $another_ap->set_is_member(0);
        
        # I most cases, $another_ap is not a coordination
        # and get_coap_members returns just $another_ap as $conjunct.
        foreach my $conjunct ($another_ap->get_coap_members()){
            $conjunct->set_afun('Apposition');
        }
    }
    
    # Rehang the comma (or semicolon or dash or bracket) under the second member of apposition.
    if (@other_ap){
        $old_head->set_parent($other_ap[0]);
    } else {
        $old_head->set_parent($first_ap);
    }
    $old_head->set_afun($old_head->form eq ',' ? 'AuxX' : 'AuxG');

    # Rehang possible AuxG (dashes or right brackets) under the last member of apposition.
    my @auxg = grep {!$_->is_member && $_->afun eq 'AuxG'} @children;
    if (@other_ap){
        foreach my $bracket (@auxg) {
            $bracket->set_parent($other_ap[-1]);
        }
    }
    
    # If the whole apposition was a conjunct of some outer coordination, is_member must stay with the head
    if ($old_head->is_member){
        $first_ap->set_is_member(1);
        $old_head->set_is_member(0);
    }
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Pdt2HamledtApos - convert appositions

=head1 DESCRIPTION

In PDT, apposition is treated as a paratactic structure
(similarly to coordinations) governed by a comma with afun=Apos.
In HamleDT, the first member of apposition governs the second member
which has afun=Apposition and governs the (optional) comma.
This block converts the former style to the latter style.

 Sample sentence:
 W. Shakespeare, an English poet, was famous.
 
 PDT:
 W. Shakespeare(parent=,;afun=Sb;is_member=1) ,(parent=was;afun=Apos)
 an English poet(parent=,;afun=Sb;is_member=1), was famous.

 HamleDT:
 W. Shakespeare(parent=was;afun=Sb;is_member=0) ,(parent=poet;afun=AuxX)
 an English poet(parent=Shakespeare;afun=Apposition;is_member=0), was famous.

HamleDT style treats apposition as a normal dependency relation,
but distinguishes it from afun=Attr.
Members of apposition are not marked with the C<is_member> attribute
except for cases when one of the members is actually a coordination, e.g.:

 Sample sentence:
 W. Shakespeare, an English poet and playwrighter, was famous.

 HamleDT:
 W. Shakespeare(parent=was;afun=Sb;is_member=0) ,(parent=and;afun=AuxX)
 an English poet(parent=and;afun=Apposition;is_member=1)
 and(parent=Shakespeare;afun=Coord;is_member=0) playwrighter(parent=and;afun=Apposition;is_member=1), was famous.
 
=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

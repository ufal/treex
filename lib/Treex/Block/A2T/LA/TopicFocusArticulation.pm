package Treex::Block::A2T::LA::TopicFocusArticulation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %TFA = (
  # tfa
  topic => 't',
  focus => 'f',
  contrastive => 'c', # not used at this stage
);

sub process_tnode {
    my ( $self, $t_node ) = @_; 
       
    my @anode_tags = $t_node->get_anodes();
    my ($tfa);
    my $node_generated = $t_node->is_generated;
    my $functor = $t_node->functor;
    
    my $lex_anode = $t_node->get_lex_anode;
    my $lex_tag = $lex_anode->tag;
    my $lex_afun = $lex_anode->afun;
    my $lex_lemma = $lex_anode->lemma;
    
    my $parent_lex_anode = $lex_anode->get_parent;  
    my $parent_afun = $parent_lex_anode->afun;
    my $parent_tag = $parent_lex_anode->tag;
    
    my @parent_children = $parent_lex_anode->get_children({ordered => 1});
    my %is_afun_of_a_parentchild;
    foreach my $parentchild ($parent_lex_anode->get_children()) {
        $is_afun_of_a_parentchild{$parentchild->afun} = 1;
    }
    
    # TODO: Not possible to implement for the moment, as such functors are not yet assigned in t_trees
    # If functor = 'MANN', tfa value = 'f'
    # if functor = 'TWEN', tfa value = 't'
    
       
     # Verbs with personal forms and infinitives are 'f'
    if ( any { $lex_tag =~ /^3/ } @anode_tags ) {
        $tfa = 'f';
    }
    elsif ( any { ( $lex_tag =~ /^2/ && $is_afun_of_a_parentchild{AuxV} ) } @anode_tags ) {
        $tfa = 'f';
    }
    
    # All newly added nodes are 't'
    if ( any { $node_generated = '1' } @anode_tags ) {
        $tfa = 't';
    }
    
    # All PREC are 't' (already implemented, just review)
    elsif ( any { $functor eq 'PREC' } @anode_tags ) {
        $tfa = 't';
    }
    # All RHEM, EXT are 'f'
    elsif ( any { $functor eq 'RHEM' || $functor eq 'EXT' } @anode_tags ) {
       $tfa = 'f';
    }
    # Adjectives, pronouns, determining nouns and participles depending on nouns are 'f'
    if ( any { $lex_afun eq 'Atr' } @anode_tags ) {
        $tfa = 'f';
    }
    # Relatives pronouns in relatives clauses are 't'
    elsif ( any { ( ( $lex_lemma eq 'qui' ) && ( $parent_afun eq 'Atr' && $parent_tag =~ /^3/ ) ) } @anode_tags ) {
        $tfa = 't';
    }
    elsif ( any { ( ( $lex_lemma eq 'qui' ) && ( $parent_tag =~ /^2/ && $parent_afun eq 'Atr' && $is_afun_of_a_parentchild{AuxV} ) ) } @anode_tags ) {
        $tfa = 't';
    }

    # Add tfa node
    my $new_node = $t_node->create_child();
    $new_node->set_tfa($tfa);
    
    return;
    
}


1;


__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::TopicFocusArticulation - using hand-written rules

=head1 DESCRIPTION

Index Thomisticus TFA (basic) automatic annotation rules

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Berta González Saavedra <Berta.GonzalezSaavedra@unicatt.it>

Marco Passarotti <marco.passarotti@unicatt.it>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

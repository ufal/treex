package Treex::Block::A2T::CS::FixCoord;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    
    my $parent  = $tnode->get_parent();

    if ( $tnode and $tnode->functor and $tnode->functor eq 'PRED' and $parent and $parent->functor and $parent->functor eq 'PRED' ) {
    
       my @coord_children = grep { $_->t_lemma and $_->t_lemma =~ /^(,|a|nebo)$/ } $tnode->get_children();
       
       if (scalar(@coord_children) == 1) { # the two PREDs should probably be coordinated by the coordinating node

         my $coord = $coord_children[0];
         my $grandparent = $parent->get_parent();
         $coord->set_parent($grandparent);
         $coord->set_functor( $coord->t_lemma eq 'nebo' ? 'DISJ' : 'CONJ' );
         $coord->set_nodetype('coap');
         $parent->set_parent($coord);
         $tnode->set_parent($coord);
         $parent->set_is_member(1);
         $tnode->set_is_member(1);

      }
   }

   return;
}


1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::FixCoord

=head1 DESCRIPTION

Searches for structures PRED ( PRED ( (a|,|nebo) ) and rehangs the nodes so that the two predicates become children of the coordinating node

=head1 TODO

=over

=item *

=back

=head1 AUTHOR

Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

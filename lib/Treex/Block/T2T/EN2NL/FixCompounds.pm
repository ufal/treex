package Treex::Block::T2T::EN2NL::FixCompounds;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $src_tnode  = $tnode->src_tnode() or return 0;
    my $parent     = $tnode->get_parent();

    return if ( $parent->is_root or $parent->t_lemma_origin =~ /rule-/ );
    
    my $t_lemma = $tnode->t_lemma // '';
    my $parent_t_lemma = $parent->t_lemma // '';
    
    if ( $t_lemma =~ /_\Q$parent_t_lemma\E$/ ){
        $parent->set_t_lemma($t_lemma);
        $parent->set_attr( 'mlayer_pos', $tnode->get_attr('mlayer_pos') );
        ($parent_t_lemma, $t_lemma) = ($t_lemma, $parent_t_lemma);
    } 
    
    if ( $parent_t_lemma =~ /_\Q$t_lemma\E$/ ) {
        log_warn("FIX: $t_lemma + $parent_t_lemma");        
        $parent->set_t_lemma_origin($parent->t_lemma_origin . ';rule-FixCompounds');
        map { $_->set_parent($parent) } $tnode->get_children();
        $tnode->remove();
        return;
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2NL::FixCompounds

=head1 DESCRIPTION

Fixing translation of compounds that end up as more nodes -- if a child node's lemma
contains the parent's lemma or the other way around (e.g. the child is 
"besturing_systeem" and the parent is "systeem"), the two nodes are merged into 
a single one containing the longer lemma.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

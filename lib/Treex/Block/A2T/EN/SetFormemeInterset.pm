package Treex::Block::A2T::EN::SetFormemeInterset;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetFormeme';

# What formeme should we assign to possesive personal pronouns (my, his, its,...):
# n:poss, adj:poss, n:attr or adj:attr?
# They have get_iset('synpos') eq 'attr', so A2T::SetFormeme selects syntpos=adj.
# However, legacy translation models expect formeme n:poss, so let's override it.
# Maybe we should change it to adj:poss (as in Czech) and re-train the models.
# In that case, it would be a question whether "John's" should be also adj:poss (or n:poss)?
# And what about possesive wh-pronouns (whose,...)?
my %HACK_TAG_TO_FORMEME = (
    'PRP$' => 'n:poss',
    'WP$'  => 'n:attr',
);

after 'process_ttree' => sub {
    my ( $self, $t_root ) = @_;
    
    foreach my $t_node ($t_root->get_descendants()) {
    
        # Check the table of hacks.
        if (my $a_node = $t_node->get_lex_anode()){
            my $new_formeme = $HACK_TAG_TO_FORMEME{$a_node->tag};
            $t_node->set_formeme($new_formeme) if $new_formeme;
        }
        
        # Distinguishing two object types (first and second) below bitransitively used verbs    
        if ($t_node->formeme =~ /^v:/){
            $self->distinguish_objects($t_node);
        }
    }
    return;
};

sub is_prep_or_conj {
    my ($self, $a_node) = @_;
    return 1 if $a_node->afun =~ /Aux[CP]/;

    # For English, we want to have the infinitive particle "to" in formeme.
    # The easiest way is to treat it as if it was Aux[CP] (although its afun=AuxV).
    # Moreover, afuns are not always reliable, so let's add all prepositions&conjunctions with tag=IN.
    return 1 if $a_node->tag =~ /^(IN|TO)$/;
    return 0;
}

override 'detect_syntpos' => sub {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    
    # numerals
    if ($a_node && $a_node->tag eq 'CD'){
        my ($t_parent) = $t_node->get_eparents({or_topological => 1});
        return 'adj' if $t_parent && $t_node->precedes($t_parent);
        return 'n';
    }
      
    return 'n' if $a_node && $a_node->tag eq 'DT';
    return super();
};

sub distinguish_objects {
    my ($self, $t_node) = @_;
    my @objects = grep { $_->formeme =~ /^n:obj/ }
        $t_node->get_echildren( { ordered => 1 } );

    return if !( @objects > 1 );

    my @firsts;
    while (@objects) {
        push @firsts, shift @objects;
        last if @objects == 0
                || !$firsts[0]->is_member
                || $firsts[0]->get_parent() != $objects[0]->get_parent();

    }

    # If both the sets of first- and second-position objects are non-empty
    if ( @firsts and @objects ) {
        foreach my $first (@firsts) {
            $first->set_formeme('n:obj1');
        }
        foreach my $second (@objects) {
            $second->set_formeme('n:obj2');
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of English t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::ES::AddSentmodPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSentmodPunct';

override 'postprocess' => sub {
    my ( $self, $a_punct, $tnode, $is_main ) = @_;
    
    # In QTLeap EN->ES translation many sentences have sentmod=imper
    # (because the main verb was imperative in English)
    # but in most (all I have seen) cases exclamation marks should not be added.
    # TODO: So when should "¡" and "!" be added?
    if ($a_punct->form eq '!'){
        if ($is_main){
            $a_punct->set_form('.');
            $a_punct->set_lemma('.');
        } else {
            $a_punct->remove();
        }
    }
    
    elsif ($a_punct->form eq '?'){
        my $a_parent = $a_punct->get_parent();
        my $punct_mark = '¿';

        my $punct = $a_parent->create_child(
        {   'form'          => $punct_mark,
            'lemma'         => $punct_mark,
            'afun'          => 'AuxK',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        });
        $punct->iset->set_pos('punc');
        $punct->shift_before_subtree($a_parent);
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddSentmodPunct - add ".", "¿", "?", "¡" and "!"

=head1 DESCRIPTION

Add punctuation-mark a-nodes corresponding to the C<sentmod> attribute of t-nodes.
This block takes care of (Spanish-specific) opening marks "¿" and "¡".

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

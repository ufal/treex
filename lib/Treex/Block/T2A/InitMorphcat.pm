package Treex::Block::T2A::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %gram2iset = (
    'aspect=proc' => 'aspect=imp',
    'aspect=cpl'  => 'aspect=perf',
    
    'definiteness=definite'   => 'definiteness=def',
    'definiteness=indefinite' => 'definiteness=ind',
    'definiteness=reduced'    => 'definiteness=red',
    
    'degcmp=pos'       => 'degree=pos',
    'degcmp=comp'      => 'degree=comp',
    'degcmp=sup'       => 'degree=sup',
    
    'diathesis=pas'    => 'voice=pass',
    
    'gender=anim'      => 'gender=masc', # Czech-specific relict: grammateme gender mixes animateness and gender
    'gender=inan'      => 'gender=masc',
    'gender=fem'       => 'gender=fem',
    'gender=neut'      => 'gender=neut',
    
    'negation=neg1'    => 'negativeness=neg',
    
    'number=sg'        => 'number=sing',
    'number=pl'        => 'number=plu',
    'number=du'        => 'number=dual',

    'numbertype=basic' => 'numtype=card',
    'numbertype=ord'   => 'numtype=ord',
    'numbertype=frac'  => 'numtype=frac',
    'numbertype=kind'  => 'numtype=gen',

    'person=1'         => 'person=1',
    'person=2'         => 'person=2',
    'person=3'         => 'person=3',
    
    'politeness=basic' => 'politeness=inf',
    'politeness=polite'=> 'politeness=pol',
    
    'tense=ant'        => 'tense=past',
    'tense=sim'        => 'tense=pres',
    'tense=post'       => 'tense=fut',
    
    'verbmod=ind'      => 'mood=ind',
    'verbmod=imp'      => 'mood=imp',
    'verbmod=cdn'      => 'mood=cnd',
);

my %syntpos2pos = (
    n => 'noun',
    v => 'verb',
    adj => 'adj',
    adv => 'adv',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    # Skip coordinations, apositions, rhematizers etc.
    return if $t_node->nodetype ne 'complex';

    # Part-of-speech
    my $syntpos = $t_node->formeme;
    $syntpos =~ s/:.*//;
    my $pos = $syntpos2pos{$syntpos};
    $pos = 'num' if $t_node->gram_sempos =~ /quant/;
    $a_node->iset->set_pos($pos) if $pos;

    # Grammatemes -> Interset features
    my $grammatemes_rf = $t_node->get_attr('gram') or return;
    while ( my ($name, $value) = each %{$grammatemes_rf}){
        if (defined $value && $self->should_fill($name, $t_node) && (my $iset_rule = $gram2iset{"$name=$value"})){
            my ($i_name, $i_value) = split /=/, $iset_rule;
            $a_node->set_iset($i_name, $i_value);
        }
    }   

    # Czech-specific relict: grammateme gender contains info about animateness (only for masculine)
    # So far, gram_gender="anim" is used instead of gram_gender="masc", so we cannot induce animateness from this value.
    my $gender = $t_node->gram_gender || '';
    if ($gender eq 'inan'){
        $a_node->iset->set_animateness('inan');
    }

    # The type of pronoun is not preserved on t-layer, but at least we know it is a pronoun
    if ($t_node->gram_sempos =~ /pron/){
        $a_node->iset->set_prontype('prn');
    }

    return;
}

sub should_fill {
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::InitMorphcat

=head1 DESCRIPTION

Fill Interset morphological categories with values derived from grammatemes and formeme.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

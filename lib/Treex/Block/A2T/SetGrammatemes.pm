package Treex::Block::A2T::SetGrammatemes;
use Moose;
use Treex::Core::Common;
use List::Pairwise qw(mapp);
extends 'Treex::Core::Block';

my %tag2sempos = (
    'adj-num'  => 'adj.quant.def',
    'adj-pron' => 'adj.pron.def.demon',
    'adj-poss' => 'n.pron.def.pers',
    'adj'      => 'adj.denot',
    'n-pron'   => 'n.pron.def.pers',
    'n-num'    => 'n.quant.def',
    'n'        => 'n.denot',
    'adv'      => 'adv.denot.grad.neg',
    'v'        => 'v',
);

my %iset2gram = (
    'aspect=imp' => 'aspect=proc',
    'aspect=perf' => 'aspect=cpl',

    'definiteness=def' => 'definiteness=definite',
    'definiteness=ind' => 'definiteness=indefinite',
    'definiteness=red' => 'definiteness=reduced',

    'degree=pos' => 'degcmp=pos',
    'degree=comp' => 'degcmp=comp',
    'degree=sup' => 'degcmp=sup',
    'degree=abs' => 'degcmp=sup',

    'voice=pass' => 'diathesis=pas',

    'gender=masc' => 'gender=anim', # Czech-specific grammateme mixing animateness and gender
    'gender=fem' => 'gender=fem',
    'gender=neut' => 'gender=neut',
    'gender=com' => 'gender=inan', # This is a hack, reusing Czech-specific gramateme for other purposes

    # possessive adjectives (overriding the adjectival gender)
    'possgender=masc' => 'gender=anim',
    'possgender=fem' => 'gender=fem',
    'possgender=neut' => 'gender=neut',
    'possgender=com' => 'gender=inan',

    'negativeness=neg' => 'negation=neg1',

    'number=sing' => 'number=sg',
    'number=plu' => 'number=pl', # TODO: Delete this, Interset 2.018 uses plur instead of plu
    'number=plur' => 'number=pl',
    'number=dual' => 'number=du',

    'numtype=card' => 'numbertype=basic',
    'numtype=ord' => 'numbertype=ord',
    'numtype=frac' => 'numbertype=frac',
    'numtype=gen' => 'numbertype=kind',

    'person=1' => 'person=1',
    'person=2' => 'person=2',
    'person=3' => 'person=3',

    'politeness=inf' => 'politeness=basic',
    'politeness=pol' => 'politeness=polite',

    'tense=past' => 'tense=ant',
    'tense=pres' => 'tense=sim',
    'tense=fut' => 'tense=post',
    'tense=aor' => 'tense=ant',
    'tense=imp' => 'tense=ant',
    'tense=pqp' => 'tense=ant',
    'tense=nar' => 'tense=ant',

    'mood=ind' => 'verbmod=ind',
    'mood=imp' => 'verbmod=imp',
    'mood=cnd' => 'verbmod=cdn',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode();

    return if ( $tnode->nodetype ne 'complex' or !$anode );

    $self->set_sempos( $tnode, $anode );

    $self->set_grammatemes_from_iset( $tnode, $anode );

    if ( ( $tnode->gram_sempos // '' ) eq 'v' ) {
        $self->set_verbal_grammatemes( $tnode, $anode );
    }

    return;
}

sub set_grammatemes_from_iset {
    my ( $self, $tnode, $anode ) = @_;
    my $isethash = $anode->iset()->get_hash();
    foreach my $name (keys(%{$isethash}))
    {
        # Use get() instead of taking the value directly from the hash. We want to avoid arrayref values!
        my $value = $anode->iset()->get($name);
        $value =~ s/\|.*//; # just first alternative
        if (my $gram = $iset2gram{"$name=$value"}){
            my ($g_name, $g_value) = split /=/, $gram;
            $tnode->set_attr("gram/$g_name", $g_value);
        }
    }
    return;
}

sub set_sempos {
    my ( $self, $tnode, $anode ) = @_;

    my $syntpos = $tnode->formeme || '';
    $syntpos =~ s/:.*//;

    if ( $syntpos eq 'n' && $anode->is_adjective ){   # adjectives in nominal usage stay adjectives
        $syntpos = 'adj';
    }

    my $subtype = $anode->is_pronoun ? 'pron' : ( $anode->is_numeral ? 'num' : '' );

    if ($syntpos eq 'adj' && $anode->match_iset(poss=>'poss', prontype=>'prs')){
        $subtype = 'poss';
    }

    if ( $tag2sempos{ $syntpos . '-' . $subtype } ) {
        $tnode->set_gram_sempos( $tag2sempos{ $syntpos . '-' . $subtype } );
    }
    elsif ( $tag2sempos{$syntpos} ) {
        $tnode->set_gram_sempos( $tag2sempos{$syntpos} );
    }
    return;
}

sub set_verbal_grammatemes {
    my ($self, $tnode, $anode) = @_;
    if (!$tnode->gram_verbmod) {$tnode->set_gram_verbmod('ind');}
    if (!$tnode->gram_tense) {$tnode->set_gram_tense('sim');}
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetGrammatemes

=head1 DESCRIPTION

A very basic, language-independent grammateme setting block for t-nodes.
Grammatemes are set based on the Interset features (and formeme)
of the corresponding lexical a-node.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

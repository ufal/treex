package Treex::Tool::Lexicon::Generation::PT;
use Moose;
use Treex::Core::Common;

my %CONJUGATION = (
    ar => {
        'ind pres' => 'o as a amos ais am',
        'ind past' => 'ei aste ou ámos astes aram',
        'ind imp'  => 'ava avas ava ávamos áveis avam',
        'ind pqp'  => 'ara aras ara áramos áreis aram',
        'ind fut'  => 'arei arás ará aremos areis arão',
        'cnd '     => 'aria arias aria aríamos aríeis ariam',
        'sub pres' => 'e es e emos eis em',
        'sub imp'  => 'asse asses asse ássemos ásseis assem',
        'sub fut'  => 'ar ares ar armos ardes arem',
    },
    er => {
        'ind pres' => 'o es e emos eis em',
        'ind past' => 'i este eu emos estes eram',
        'ind imp'  => 'ia ias ia íamos íeis iam',
        'ind pqp'  => 'era eras era êramos êreis eram',
        'ind fut'  => 'erei erás erá eremos ereis erão',
        'cnd '     => 'eria erias eria eríamos eríeis eriam',
        'sub pres' => 'a as a amos ais am',
        'sub imp'  => 'esse esses esse êssemos êsseis essem',
        'sub fut'  => 'er eres er ermos erdes erem',
    },
    ir => {
        'ind pres' => 'o es e imos is em',
        'ind past' => 'i iste iu imos istes iram',
        'ind imp'  => 'ia ias ia íamos íeis iam',
        'ind pqp'  => 'ira iras ira íramos íreis iram',
        'ind fut'  => 'irei irás irá iremos ireis irão',
        'cnd '     => 'iria irias iria iríamos iríeis iriam',
        'sub pres' => 'a as a amos ais am',
        'sub imp'  => 'isse isses isse íssemos ísseis issem',
        'sub fut'  => 'ir ires ir irmos irdes irem',
    },
    verb_estar => {
        'ind pres' => 'estou estás está estamos estais estão',
        'ind past' => 'estive estiveste esteve estivemos estivestes estiveram',
        'ind imp'  => 'estava estavas estava estávamos estáveis estavam',
        'ind pqp'  => 'estivera estiveras estivera estivéramos estivéreis estiveram',
        'ind fut'  => 'estarei estarás estará estaremos estareis estarão',
        'cnd '     => 'estaria estarias estaria estaríamos estaríeis estariam',
        'sub pres' => 'esteja estejas esteja estejamos estejais estejam',
        'sub imp'  => 'estivesse estivesses estivesse estivéssemos estivésseis estivessem',
        'sub fut'  => 'estiver estiveres estiver estivermos estiverdes estiverem',
    },
    verb_ser => {
        'ind pres' => 'sou és é somos sois são',
        'ind past' => 'fui foste foi fomos fostes foram',
        'ind imp'  => 'era eras era éramos éreis eram',
        'ind pqp'  => 'fora foras fora fôramos fôreis foram',
        'ind fut'  => 'serei serás será seremos sereis serão',
        'cnd '     => 'seria serias seria seríamos seríeis seriam',
        'sub pres' => 'seja sejas seja sejamos sejais sejam',
        'sub imp'  => 'fosse fosses fosse fôssemos fôsseis fossem',
        'sub fut'  => 'for fores for formos fordes forem',
    },
    verb_ir => {
        'ind pres' => 'vou vais vai vamos ides vão',
        'ind past' => 'fui foste foi fomos fostes foram',
        'ind imp'  => 'ia ias ia íamos íeis iam',
        'ind pqp'  => 'fora foras fora fôramos fôreis foram',
        'ind fut'  => 'irei irás irá iremos ireis irão',
        'cnd '     => 'iria irias iria iríamos iríeis iriam',
        'sub pres' => 'vá vás vá vamos vades vão',
        'sub imp'  => 'fosse fosses fosse fôssemos fôsseis fossem',
        'sub fut'  => 'for fores for formos fordes forem',
    }
);



sub best_form_of_lemma {
    my ( $self, $lemma, $iset ) = @_;
    my $pos = $iset->pos;
    if ($pos eq 'verb'){
        my ($stem, $class) = ('', '');

        # check irregular verbs first
        if ($lemma =~ /^(ir|ser|estar)$/){
            $class = "verb_$lemma";
        } else {
            ($stem, $class) = ($lemma =~ /^(.+)(ar|er|ir)$/);
        }
        return $lemma if !$class;
        my $mood = $iset->mood;
        my $tense = $iset->tense;
        my $person = $iset->person || 3;
        my $forms = $CONJUGATION{$class}{"$mood $tense"};
        return $lemma if !$forms;
        $person += 3 if $iset->number eq 'plur';
        my $ending = (split / /, $forms)[$person - 1];
        return $stem.$ending;
    }
    elsif ($pos =~/noun|adj/){
        if ($iset->degree eq 'sup'){
            $lemma =~ s/[oe]?$/íssimo/;
        }
        if ($pos eq 'adj' && $iset->gender eq 'fem'){
            $lemma =~ s/ão$/ona/; # grandão -> grandona
            $lemma =~ s/[oe]?$/a/ if $lemma !~ /a$/;
        }
        if ($iset->number eq 'plur'){
            $lemma =~ s/ão$/ães/ or
            $lemma = $lemma.'s';
        }
    }
    return $lemma;
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::Generation::PT

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::Generation::PT;
 my $generator = Treex::Tool::Lexicon::Generation::PT->new();

 my $iset = Lingua::Interset::FeatureStructure->new({pos=> 'verb', number=>'sing', mood=>'ind', person=>3, tense=>'pres'});
 print $generator->best_form_of_lemma('gostar', $iset);
 #Should print:
 # gosta

=head1 DESCRIPTION

Draft of Portuguese verbal conjugation (and simple noun+adjective inflection)
based on http://en.wikipedia.org/wiki/Portuguese_verb_conjugation.
This is just a placeholder for the real morphological module by LX-Center.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

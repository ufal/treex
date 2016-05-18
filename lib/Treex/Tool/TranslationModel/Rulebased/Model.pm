package Treex::Tool::TranslationModel::Rulebased::Model;
use utf8;
use Moose;
use Treex::Core::Common;

with 'Treex::Tool::TranslationModel::Model';

# TODO it is for English-to-Czech only, but this is not parametrizable at the moment

# some overrdies

sub source { return "rulebased"; }

sub load { return; }

sub _create_submodel { return; }

sub _get_transl_variants { return; }


# transformation rules

my %full_match_rules = (
    'be' => 'být',
    'have' => 'mít',
    'do' => 'dělat',
    'and' => 'a',
    'or' => 'nebo',
    'but' => 'ale',
    'therefore' => 'proto',
    'that' => 'který',
    'which' => 'který',
    'what' => 'co',
    'each' => 'každý',
    'other' => 'jiný',
    'then' => 'pak',
    'also' => 'také',
    'as' => 'tak',
    'all' => 'všechen',
    'this' => 'tento',
    'these' => 'tyto',
    'many' => 'mnoho',
    'only' => 'jen',
    'main' => 'hlavní',
    'mainly' => 'hlavně',
    'one' => '1',
    'two' => '2',
    'three' => '3',
    'four' => '4',
    'five' => '5',
    'six' => '6',
    'seven' => '7',
    'eight' => '8',
    'nine' => '9',
    'ten' => '10',
);

my %suffix_rules = (
    n => [
        ['sion$', 'se'],
        ['tion$', 'ce'],
        ['ison$', 'ace'],
        ['em$', 'ém'],
        ['ty$', 'ta'],
        ['is$', 'e'],
        ['ine?$', 'ín'],
        ['ing$', 'ování'],
        ['cy$', 'ce'],
        ['y$', 'ie'],
    ],
    adj => [
        ['tial$', 'ciální'],
        ['ble$', 'bilní'],
        ['ant$', 'antní'],
        ['ated$', 'ovaný'],
        ['ic$', 'ický'],
        ['ical$', 'ický'],
        ['ive$', 'ivní'],
        ['ar$', 'ární'],
        ['al$', 'ální'],
        ['ed$', 'ovaný'],
        ['ing$', 'ující'],
        ['$', 'ový'],
    ],
    adv => [
        ['tially$', 'ciálně'],
        ['bly$', 'bilně'],
        ['antly$', 'antně'],
        ['atedly$', 'ovaně'],
        ['ically$', 'icky'],
        ['ively$', 'ivně'],
        ['ally$', 'álně'],
        ['ly$', 'ně'],
        ['$', 'ově'],
    ],
    v => [
        ['ate$', 'ovat'],
        ['ing$', 'ující'],
        ['y$', 'iovat'], # iovat
        ['$', 'ovat'],
    ],
);

my @deduplication_rules = (
    ['aa', 'á'],
    ['ee', 'í'],
    ['oo', 'ů'],
    ['(.)\K\1', ''],
);

my @lemma_rules = (
    ['^\Ky', 'J'],
    ['[aeiou]\Ky', 'J'],
    ['c(?=[eiy])', 'C'], # protect 'ce', 'ci', 'cy'
    ['[aeiouy].*\K[ey]$', ''], # remove final 'e' and 'y', unless it is the only vowel
    
    # consonants
    ['th', 'T'],
    ['ck', 'K'],
    ['ph', 'F'],
    ['sh', 'Š'],
    ['ch$', 'CH'],
    # ['ch$', 'K'],
    ['ch', 'Č'],
    ['cz', 'Č'],
    ['qu$', 'K'],
    ['qu', 'KV'],
    ['gh', 'CH'],
    ['gu', 'GV'],
    # ['g(?=[ei])', 'Ž'],
    ['dg', 'DŽ'],
    ['g$', 'Ž'],
    # ['t(?=ur$)', 'Č'],
    # ['j', 'Ž'],
    ['w', 'V'],
    # ['[aeiou-]\Kc', 'K'], # c after vowel or dash
    # ['c(?!$)', 'K'], # non-final c
    ['c', 'K'],
    
    # vowels
    ['ah', 'Á'],
    ['eh', 'É'],
    ['oh', 'Ó'],
    ['uh', 'Ú'],
    ['ai', 'É'],
    ['ea(?!$)', 'Í'],
    ['ie(?!$)', 'Í'],
);

my %sempos2pos = (
    adj => 'A',
    adv => 'D',
    n => 'N',
    v => 'V',
    x => 'X',
);

# override 'get_translations' => sub {
sub get_translations {
    my ($self, $lemma, $features_ar) = @_;

    my $features = $self->feats_ar2hr($features_ar);
    my $tag = $sempos2pos{$features->{short_sempos} // 'x'} // 'X';

    my $lemmas = $self->transform_lemma($lemma, $features);

    my $prob = 1;
    my @variants = map { { 
            label => $_ . '#' . $tag,
            prob => ($prob -= 0.1),
            source => $self->source,
        } } @$lemmas;

    # Ordering of keys in a Perl hash is not deterministic.
    # However, we want our experiments deterministic,
    # so we need stable (lexicographic) sorting also for variants with the same prob.
    my @results = sort {$b->{prob} <=> $a->{prob} or $a->{label} cmp $b->{label}} @variants;
    return @results;
}

sub transform_lemma {
    my ($self, $lemma, $features) = @_;

    # non-alphabetical: skip
    if ($lemma !~ /^[\p{L}-]*$/) {
        return [$lemma];
    }

    # full word
    if (defined $full_match_rules{$lemma}) {
        return [$full_match_rules{$lemma}];
    }

    # suffix
    my $suffix = '';
    my $sempos = $features->{short_sempos};
    foreach my $rule (@{$suffix_rules{$sempos}}) {
        my $from = $rule->[0];
        my $to = $rule->[1];
        if ($lemma =~ s/$from//) {
            $suffix = $to;
            last;
        }
    }
    
    # deduplication (double letter -> single letter)
    foreach my $rule (@deduplication_rules) {
        my $from = $rule->[0];
        my $to = $rule->[1];
        $lemma =~ s/$from/$to/g;
    }

    # lemma
    foreach my $rule (@lemma_rules) {
        my $from = $rule->[0];
        my $to = $rule->[1];
        $lemma =~ s/$from/$to/g;
    }
    if ($suffix && $lemma =~ /Ž$/) {
        substr $lemma, -1, 1, 'g';
    }
    $lemma = lc $lemma;

    my @result = ($lemma . $suffix);

    # add a secondary candidate: make prefinal vowel longer
    my %lengthening = (a => 'á', e => 'é', i => 'í', o => 'ó');
    my $lemmaa = $lemma;
    if ($lemmaa =~ /([aeio]).$/) {
        substr $lemmaa, -2, 1, $lengthening{$1};
        push @result, ($lemmaa . $suffix);
    }

    return \@result;
}

sub feats_ar2hr {
    my ($self, $features) = @_;

    my %result;
    foreach my $feature (@$features) {
        my ($key, $value) = split /=/, $feature, 2;
        $result{$key} = $value;
    }

    return \%result;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::TranslationModel::Rulebased::Model - Simple EN-to-CS rulebased t_lemma translation.

=head1 SYNOPSIS

 # From command line
 treex -Len -Ssrc Read::Sentences from=input.txt Scen::EN2CS resegment=1 lemma_models='rulebased 1.0 dummy' Write::Sentences to=output.txt join_resegmented=1
 
=item DESCRIPTION

A simple rule-based translation tool for English-to-Czech translation
on t_lemmas -- to be used instead of 'real' static and maxent models.
Or probably even in conjuction with them? (TODO)

It uses the standard L<Treex::Tool::TranslationModel::Model> interface
(but does not use any model file, so just use a dummy empty file instead).

Uses the following:

=over

=item a shortlist of approx. 40 lemmas, generally focusing on words that are function words but nevertheless get their own t-node

=item approx. 40 sempos-based translation rules for word endings

=item approx. 40 transliteration rules

=back

The rest is done by the standard TectoMT pipeline.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



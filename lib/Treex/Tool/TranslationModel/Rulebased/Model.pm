package Treex::Tool::TranslationModel::Rulebased::Model;
use utf8;
use Moose;
use Treex::Core::Common;

with 'Treex::Tool::TranslationModel::Model';

has skip_names => ( is => 'rw', isa => 'Bool', default => 0 );

# TODO it is for English-to-Czech only, but this is not parametrizable at the moment

# some overrdies

sub source { return "rulebased"; }

sub load { return; }

sub _create_submodel { return; }

sub _get_transl_variants { return; }


# transformation rules

my %full_match_rules = (
    'be' => 'být#V',
    'have' => 'mít#V',
    'do' => 'dělat#V',
    'and' => 'a#J',
    'or' => 'nebo#J',
    'but' => 'ale#J',
    'therefore' => 'proto#J',
    'that' => 'který#P',
    'which' => 'který#P',
    'what' => 'co#P',
    'each' => 'každý#A',
    'other' => 'jiný#A',
    'then' => 'pak#D',
    'also' => 'také#D',
    'as' => 'tak#D',
    'all' => 'všechen#P',
    'this' => 'tento#P',
    'these' => 'tento#P',
    'many' => 'mnoho#C',
    'only' => 'jen#D',
    'main' => 'hlavní#A',
    'mainly' => 'hlavně#D',
    'one' => '1#C',
    'two' => '2#C',
    'three' => '3#C',
    'four' => '4#C',
    'five' => '5#C',
    'six' => '6#C',
    'seven' => '7#C',
    'eight' => '8#C',
    'nine' => '9#C',
    'ten' => '10#C',
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
        ['ous$', 'ální'],
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
        ['ously$', 'álně'],
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

# TODO lemma#SUFFIX -- can match suffix but do not have to

my @lemma_rules = (
    ['^\Ky', 'J'],
    ['[aeiou]\Ky', 'J'],
    ['c(?=[eiy])', 'C'], # protect 'ce', 'ci', 'cy'
    ['[aeiouy]\Kse', 'Ze'], # <vowel>se -> ze
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

# in the order of likelihood of generating
my @semposes = ('n', 'adj', 'v', 'adv', 'x');

# override 'get_translations' => sub {
sub get_translations {
    my ($self, $lemma, $features_ar) = @_;

    my $features = $self->feats_ar2hr($features_ar);
    my $labels = $self->generate_labels($lemma, $features);

    my $prob = 0.5;
    my @variants;
    foreach my $label (@$labels) {
        log_debug("RB: adding $label with $prob", 1);
        push @variants, { 
            label => $label,
            prob => $prob,
            source => $self->source,
        };
        $prob /= 2;
    }

    # Ordering of keys in a Perl hash is not deterministic.
    # However, we want our experiments deterministic,
    # so we need stable (lexicographic) sorting also for variants with the same prob.
    my @results = sort {$b->{prob} <=> $a->{prob} or $a->{label} cmp $b->{label}} @variants;
    return @results;
}

my %lengthening = (a => 'á', e => 'é', i => 'í', o => 'ó');
sub generate_labels {
    my ($self, $lemma, $features) = @_;

    my $sempos = $features->{short_sempos};
    my @result;
    
    if ($lemma !~ /^[\p{L}-]*$/) {
        # non-alphabetical: skip
        push @result, $self->l_s($lemma, $sempos);
    # if (lcfirst $lemma ne $lemma) {
    # if ($features->{capitalized}) {
    } elsif ($self->skip_names && $features->{ne_type}) {
        # named entity: skip
        push @result, $self->l_s($lemma, $sempos);
    } elsif (defined $full_match_rules{$lemma}) {
        # full word
        push @result, $full_match_rules{$lemma};
    } else {
        # prefer the specified sempos, but go over all semposes
        foreach my $sem ($sempos, @semposes) {
            # add a candidate
            my ($new_lemma, $suffix) = $self->transform_lemma($lemma, $sem);
            push @result, $self->l_s($new_lemma . $suffix, $sem);

            # add a secondary candidate: make prefinal vowel longer
            if ($new_lemma =~ /([aeio]).$/) {
                substr $new_lemma, -2, 1, $lengthening{$1};
                push @result, $self->l_s($new_lemma . $suffix, $sem);
            }
        }
    }
    
    return \@result;
}

sub transform_lemma {
    my ($self, $lemma, $sempos) = @_;

    # suffix
    my $suffix = '';
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

    return ($lemma, $suffix);
}

# lemma & sempos -> lemma#tag
my %sempos2pos = (
    adj => 'A',
    adv => 'D',
    n => 'N',
    v => 'V',
    x => 'X',
);
sub l_s {
    my ($self, $lemma, $sempos) = @_;

    my $tag = $sempos2pos{$sempos // 'x'} // 'X';
    return $lemma . '#' . $tag;
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



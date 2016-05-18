package Treex::Block::A2A::CS::FixCasing;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';
use Treex::Tool::Depfix::CS::SimpleTranslator;
use Treex::Tool::Depfix::CS::DiacriticsStripper;

has translate => ( is => 'rw', isa => 'Bool', default => 0 );

my %do_not_uc = (
    eur => 1,
    euro => 1,
    muslim => 1,
    islam => 1,
    protestant => 1,
    media => 1,
    internet => 1,
    hotel => 1,
    management => 1,
    manager => 1,
    premier => 1,
    general => 1,
    president => 1,
    lord => 1,
    sir => 1,
);

sub fix {
    my ( $self, $dep, $gov ) = @_;

    my $endep = $self->en($dep);
    if ( defined $dep->ord && $dep->ord != 1
        && defined $endep
        && defined $endep->ord && $endep->ord != 1
        && $dep->form ne $endep->form
    ) {
        
        # do not uc what should not be uc'd
        if ($endep->form =~ /[A-Z]/ && $do_not_uc{ lc($endep->lemma) }) {
            return;
        }

        my $old_form = $dep->form;
        my $new_form = $dep->form;
        
        my $form_imatches = lc($dep->form) eq lc($endep->form);
        my $lemma_imatches = 0;
        {
            my $dep_lemma =
            Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
                Treex::Tool::Lexicon::CS::truncate_lemma(
                    lc ($dep->lemma), 1));
            my $en_lemma =
            Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
                lc ($endep->lemma));
            my $dep_form =
            Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
                lc ($dep->form));
            my $en_form =
            Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
                lc ($endep->form));
            $lemma_imatches =
                ($dep_lemma eq $en_lemma)
                || ($dep_form eq $en_form)
                || ($dep_form eq $en_lemma)
                || ($dep_lemma eq $en_form);
        }
        
        if ($form_imatches) {
            $new_form = $self->try_to_translate($dep, $endep) // $endep->form;
        }
        elsif ($lemma_imatches) {
            my $en_form = $endep->form;

            if ($en_form =~ /^[a-z]*$/) {
                # apple
                $new_form = $self->try_to_translate($dep, $endep)
                    // lc ($dep->form);
            }
            elsif ($en_form =~ /^[A-Z][a-z]*$/) {
                # Apple
                $new_form = ucfirst $new_form;
            }
            # elsif ($en_form =~ /^(\p{isUpper}*)$/) {
                # APPLE
                # do not fix: eg. en = HRK, cs nom = HRK, but cs gen = HRKu
                # $new_form = uc $new_form;
                # }
            else {
                # something like iPod, VMware, HRKu
                # (note that the form DOES NOT imatch)
                my $common_length =
                    length($new_form) < length($en_form)
                    ? length($new_form) : length($en_form);
                my $form_builder = '';
                for (my $char = 0; $char < $common_length; $char++) {
                    my $en_char = substr $en_form, $char, 1;
                    my $cs_char = substr $new_form, $char, 1;
                    my $chars_match = $cs_char eq $en_char;
                    my $chars_imatch = lc ($cs_char) eq lc ($en_char);
                    if ( !$chars_match && $chars_imatch ) {
                        $cs_char = $en_char;
                    }
                    $form_builder .= $cs_char;
                }
                $form_builder .= substr $new_form, $common_length;
                $new_form = $form_builder;
            }
        }

        if ($new_form ne $old_form) {
            $self->logfix1( $dep, "Casing" );
            $dep->set_form($new_form);
            $self->logfix2($dep);
        }
    }
}

sub try_to_translate {
    my ($self, $dep, $endep) = @_;

    my $new_form = undef;
    
    # if the English word is in lowercase,
    # it is uncommon to keep it untranslated
    # (the approximate match and the X@ tag suggest
    # that the word was left untranslated)
    if ( $self->translate && $dep->tag =~ /^X@/ && $endep->form =~ /^[a-z]*$/ ) {
        my $en_lc_lemma = lc $endep->lemma;
        my $translator =
            Treex::Tool::Depfix::CS::SimpleTranslator->new();
        # TODO also change the POS (the translator already returns that)
        my ($translation) =
            $translator->translate_lemma( $en_lc_lemma );
        $translation =~ s/_.*$//;
        if (defined $translation && $translation ne $en_lc_lemma ) {
            $new_form = $translation;
        }
    }

    return $new_form;
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixCasing

=head1 DESCRIPTION

Finds pairs of aligned words that approximately match in form or lemma
and tries to match the casing of the Czech translation
to the English original.

It also tries to guess the situation where a word was not translated
although it should have been and tries to translate it at least somehow.


hacks:

a manual list of words that should not be uppercased:
Internet
Management, Manager
en: Muslim -> muslim (all of them) / Muslim (Bosňák)
Protestant
...

known problems:
Finance Minister
ord != 1 is not enough, there might be non-words at the beginning of the sentence...

unlear cases:
Hotel
Lord, Sir, Miss
zoo/ZOO
Plan

TODO:

When lowercasing, it is often the case that the system failed to translate a word, believing it to be a named entity when in fact it is not. --> try to retranslate in such case?
(WMT10: Director, ZOO, 'S, Unleashed, Going Under, Euro)

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

package Treex::Tool::Lexicon::Generation::CS;

# I cannot modify CzechMorpho, since I don't have write permision
# for /mnt/h/repl/perl_repo/lib/perl/5.8.8/CzechMorpho.pm
# There is a bug in CzechMorpho due to analysis used in genaration,
# e.g. it generates "pesech" as a form of lemma "pes".
# This module is a temporary hack how to solve it.

use Treex::Core::Common;
use utf8;
use Readonly;
use LanguageModel::FormInfo;
use Class::Std;

use CzechMorpho;
my $generator = CzechMorpho::Generator->new();
my $analyzer  = CzechMorpho::Analyzer->new();

use Treex::Tool::Lexicon::CS::Prefixes;

# If the string is longer than 249 bytes, the C code will die.
# For safety, we set the limit a bit lower.
# For speed,  we add another limit on (possibly multi-byte Unicode) characters.
my $MAXBYTES = 200;
my $MAXCHARS = 120;

sub _split_tags {
    my $lemma_and_tags = shift;
    my ( $pdt_lemma, $tags ) = split /\t/, $lemma_and_tags, 2;
    log_fatal(
        "CzechMorpho changed in r3720 its internal separator of tags from + to tabulator.\n"
            . "Make sure you have the new version of CzechMorpho installed (in " . $INC{'CzechMorpho.pm'} . ").\n"
            . "The string '$lemma_and_tags' contains no tabulator."
        )
        if !defined $tags;
    return ( $pdt_lemma, $tags );
}

sub forms_of_lemma {

    my ( $self, $lemma, $arg_ref ) = @_;

    log_debug(
        'FORMS_OF_LEMMA' . "\t" . join(
            "\t", $lemma, $arg_ref->{tag_regex} // '', $arg_ref->{limit} // '', $arg_ref->{guess} // '',
            $arg_ref->{no_capitalization} // ''
        ), 1
    );

    log_fatal('No lemma given to forms_of_lemma()') if !defined $lemma;

    return if length $lemma > $MAXCHARS;
    my $tag_regex = $arg_ref->{'tag_regex'} || '.*';
    my $limit     = $arg_ref->{'limit'}     || 0;
    my $guess = defined $arg_ref->{'guess'} ? $arg_ref->{'guess'} : 1;

    # By default, if a lemma starts with a capital letter, return also capitalized form
    my $no_capitalization = $arg_ref->{'no_capitalization'} || 0;

    # prepare special utf8 glyphs for conversion (like three dots)
    my $dlemma = DowngradeUTF8forISO2::downgrade_utf8_for_iso2($lemma);
    {
        use bytes;
        return if length $dlemma > $MAXBYTES;
    }
    $dlemma =~ s/&#241;/ň/g;    # "ñ" is not in latin2, "ň" looks similar

    # get numbered pdt-lemmata
    my @pdt_lemmata = $self->pdt_lemmata_for_plain_lemma($dlemma);

    # Generate all forms for all the pdt-lemmata
    my @all_forms = ();
    foreach my $pdt_lemma (@pdt_lemmata) {

        #TODO: try to add the regex here instead of '*'
        my $forms_tags = _to_utf8( CzechMorpho::morpho_generate_all_swig( _from_utf8($pdt_lemma), '*' ) );
        my $origin = 'database';
        if ( !$forms_tags && $guess ) {
            ( $origin, $forms_tags ) = $self->_guess_forms($lemma);
        }
        foreach my $form_tag ( split /\|/, ( $forms_tags || '' ) ) {
            my ( $form, $tag ) = _split_tags($form_tag);
            my $form_info = LanguageModel::FormInfo->new(
                {
                    form   => $form,
                    lemma  => $pdt_lemma,
                    tag    => $tag,
                    origin => $origin
                }
            );
            push @all_forms, $form_info;
        }
    }

    # prune @all_forms
    $tag_regex = qr{$tag_regex};    #compile regex
    my $found = 0;
    my @forms;
    foreach my $fi (@all_forms) {
        next if $fi->get_tag() !~ $tag_regex;
        if ( !$no_capitalization && $fi->get_lemma() =~ /^\p{IsUpper}/ ) {
            $fi->set_form( ucfirst $fi->get_form() );
        }
        push @forms, $fi;
        last if $limit and ( ++$found >= $limit );
    }
    log_debug( "FORMS_OF_LEMMA RETURN\t" . join( "\t", @forms ), 1 );
    return (
        grep { $_->get_tag =~ /-$/ } @forms,
        grep { $_->get_tag !~ /-$/ } @forms,
    );
}

# Note that this actually returns a random form (because the forms are not sorted).
# This method makes it just easy to fallback from LanguageModel::MorphoLM to this class.
sub best_form_of_lemma {
    my ( $self, $lemma, $tag_regex ) = @_;
    my ($form_info) = $self->forms_of_lemma( $lemma, { tag_regex => $tag_regex } );
    return $form_info ? $form_info : undef;
}

sub _guess_forms {
    my ( $self, $lemma ) = @_;
    my $ft;
    return ( 'guess-ova',    $ft ) if $ft = $self->_guess_forms_of_ova_cka_ska($lemma);
    return ( 'guess-prefix', $ft ) if $ft = $self->_guess_forms_of_prefixed($lemma);
    return;
}

sub _guess_forms_of_ova_cka_ska {
    my ( $self, $lemma ) = @_;
    my ( $radix, $suffix ) = ( $lemma =~ /(.*)(ov|ck|sk)á$/ );
    return if !$radix;

    #HACK: because of lowercased translation dictionaries
    $radix = ucfirst $radix;
    my @suffs = map { $suffix . $_ } qw(dummy á é é ou á é ou);
    return join '|', map { $radix . $suffs[$_] . "\tNNFS" . $_ . '-----A----' } ( 1 .. 7 );
}

sub _guess_forms_of_prefixed {
    my ( $self,   $lemma ) = @_;
    my ( $prefix, $radix ) = Treex::Tool::Lexicon::CS::Prefixes::divide($lemma);
    return if !$prefix;
    my @forms = $self->forms_of_lemma($radix);
    return if !@forms;
    return join '|', map { $prefix . $_->get_form() . "\t" . $_->get_tag() } @forms;
}

sub _from_utf8 {
    my ($string) = @_;
    return $CzechMorpho::U2I->convert($string);
}

sub _to_utf8 {
    my ($string) = @_;
    $string = $CzechMorpho::I2U->convert($string);
    Encode::_utf8_on($string);
    return $string;
}

# returns lemmata in PDT style
sub pdt_lemmata_for_plain_lemma {
    my ( $self, $plain_lemma ) = @_;

    # There is a bug in CzechMorpho --
    # it uses pipe symbol (|) as a delimiter, but it does not escape it.
    # (It expects, it cannot appear in other tokens than "|", but that's a matter of tokenization.)
    # Since CzechMorpho is not at CPAN (but needs installation), we must hack it here.
    $plain_lemma =~ s{\|}{%7C}g;

    return map { $_->{lemma} } grep { $self->can_be_tag_of_lemma( $_->{tag} ) } $analyzer->analyze($plain_lemma);

    #   this version crashed for the following lemmas: 'slovák', 'británie'
    #
    #    # We analyze the plain lemma as if it was a word form.
    #    # Unfortunatelly, morpho_analyze_swig uses Latin2 encoding,
    #    # so we convert it from and to utf8 on the fly.
    #    #<<<
    #    my @lemmata_and_tags =
    #        split /\|/,                            # 4. string -> array
    #        _to_utf8(                              # 3. latin2 -> utf8
    #            CzechMorpho::morpho_analyze_swig(  # 2. analyze to string
    #                _from_utf8($plain_lemma)       # 1. utf8 -> latin2
    #            )
    #        );
    #    #>>>
    #
    #    if ( !@lemmata_and_tags ) {
    #        return $plain_lemma;
    #    }
    #
    #    # We return all the pdt-lemmata with "lemma-compatible" tags.
    #    # E.g. $plain_lemma == 'pes';
    #    # @lemmata_and_tags == (
    #    #   "pes_^(zvíře)\tNNMS1-----A----",
    #    #   "peso_^(měna_někt._jihoamer._zemí)\tNNNP2-----A----" );
    #    # @pdt_lemmata == ('pes_^(zvíře)');
    #    # ("peso" is not a good lemma because it has genitive in its tag.)
    #    my @pdt_lemmata;
    #    foreach my $lemma_and_tags (@lemmata_and_tags) {
    #        my ( $pdt_lemma, $tags ) = _split_tags($lemma_and_tags);
    #        if ( any { $self->can_be_tag_of_lemma($_) } split /\//, $tags ) {
    #            $pdt_lemma =~ s{%7C}{|}g;
    #            push( @pdt_lemmata, $pdt_lemma );
    #        }
    #    }
    #
    #    # If the compatibility check was too strict, try another heuristic:
    #    # Is $plain_lemma a prefix of $pdt_lemma?
    #    if ( !@pdt_lemmata ) {
    #        foreach my $lemma_and_tags (@lemmata_and_tags) {
    #            my ( $pdt_lemma, $tags ) = _split_tags($lemma_and_tags);
    #            if ( $pdt_lemma =~ /^$plain_lemma($|[_-])/ ) {
    #                push( @pdt_lemmata, $pdt_lemma );
    #            }
    #        }
    #    }
    #
    #    return @pdt_lemmata;
}

sub can_be_tag_of_lemma {
    my ( $self, $tag ) = @_;
    my ( $pos, $subpos, $gender, $number, $case ) = ( $tag =~ /^(.)(.)(.)(.)(.)/ );

    # Nouns must be in nominative (case=1) or special (case=X)
    return 0 if $pos eq 'N' && $case =~ /[2-7]/;

    # Lemmas are usually in singular, except pluralia tanta (dveře)
    return 0 if $pos eq 'N' && $number ne 'S';

    # Verbs must be in infinitive (subpos=f)
    return 0 if $pos eq 'V' && $subpos ne 'f';

    # All other tags can be lemmas (let's say, to make it robust)
    return 1;
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::Generation::CS

=head1 VERSION

0.01

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::Generation::CS;
 my $generator = Treex::Tool::Lexicon::Generation::CS->new();
 
 my @forms = $generator->forms_of_lemma('moci');
 foreach my $form_info (@forms){
     print join("\t", $form_info->get_form(), $form_info->get_tag()), "\n";
 }
 #Should print something like:
 # může   VB-S---3P-AA---I
 # mohou  VB-P---3P-AA--1I
 # mohl   VpYS---XR-AA---I
 #etc.

 # Now print only past participles of 'moci'
 # and don't use morpho guesser (default is guess=>1)
 @forms = $generator->forms_of_lemma('moci',
    {tag_regex => '^Vp', guess=>0});
 foreach my $form_info (@forms){
     print $form_info->to_string(), "\n";
 }

=head1 DESCRIPTION

Wrapper for Jan Ptáček's wrapper for Jan Hajič's Czech morphology tools. :-0

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

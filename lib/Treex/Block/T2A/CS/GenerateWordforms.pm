package Treex::Block::T2A::CS::GenerateWordforms;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS;
use File::Spec;

# supporting auto-download of required data-files
sub get_required_share_files {
    my ($self) = @_;
    return ( File::Spec->catfile( 'data', 'models', 'language', 'cs', 'syn.pls.gz' ) );
}

#use Smart::Comments;

use Treex::Tool::Lexicon::Generation::CS;
use Treex::Tool::LM::MorphoLM;

my ( $morphoLM, $generator );

sub BUILD {
    my $self = shift;

    return;
}

sub process_start {
    my $self = shift;

    $morphoLM  = Treex::Tool::LM::MorphoLM->new();
    $generator = Treex::Tool::Lexicon::Generation::CS->new();

    $self->SUPER::process_start();

    return;
}

# TODO (MP): $DEBUG => 1; a zjistit proc je tolik slov nepokrytych slovnikem: vetsinou jsou spatne zadany tagy

my @CATEGORIES = qw(pos subpos gender number case possgender possnumber
    person tense grade negation voice reserve1 reserve2);

sub process_anode {
    my ( $self, $a_node ) = @_;
    if ( _should_generate($a_node) ) {
        my $form = _generate_word_form($a_node);

        $a_node->set_form( $form->get_form() );
        $a_node->set_tag( $form->get_tag() );
    }
    elsif ( !defined $a_node->form ) {
        $a_node->set_form( $a_node->lemma );
    }
    return;
}

sub _should_generate {
    my $a_node = shift;
    return (
        defined $a_node->get_attr('morphcat/pos')
            and $a_node->get_attr('morphcat/pos') !~ /[ZJR!]/    # neohybat neohebne a ty, co uz ohnute jsou (znak !)
            and ( $a_node->get_attr('morphcat/subpos') ne 'c' || !defined( $a_node->form ) )    # tvary kondicionalnich AuxV uz jsou urcene
            and $a_node->lemma =~ /^(\w|#Neg)/                                                  # mimo #PersPron a cislicove cislovky
    );
}

sub _generate_word_form {
    my $a_node = shift;
    my $lemma  = $a_node->lemma;

    # digits, abbreviations etc. are not attempted to be inflected
    return Treex::Tool::LM::FormInfo->new( { form => $lemma, lemma => $lemma, tag => 'C=-------------' } )
        if $lemma =~ /^[\d,\.\ ]+$/ or $lemma =~ /^[A-Z]+$/;
    return Treex::Tool::LM::FormInfo->new( { form => 'ne', lemma => 'ne', tag => 'TT-------------' } )
        if $lemma eq '#Neg';

    # "tři/čtyři sta" not "stě" (forms "sta" and "stě" differ only in the 15th position of tag)
    return Treex::Tool::LM::FormInfo->new( { form => 'sta', lemma => 'sto-2`100', tag => 'NNNP4-----A----', count => 0 } )
        if $lemma eq 'sto' && $a_node->get_attr('morphcat/case') eq '4'
            && any {
                my $number = Treex::Tool::Lexicon::CS::number_for( $_->lemma );
                defined $number && $number > 2;
        }
        $a_node->get_children();

    # Let the MorphoLM decides whether to use "5 let" or "5 roků"
    if ( $lemma eq 'rok' ) {
        $a_node->set_attr( 'morphcat/gender', '.' );
    }

    my ( $tag_regex, $partial_regexps_ref ) = _get_tag_regex($a_node);

    # resolving spurious nouns-adjectives like 'nadřízený' - try lemma 'nadřízená'
    if ($a_node->get_attr('morphcat/pos') eq 'N'
        && $a_node->get_attr('morphcat/gender') eq 'F'
        && $lemma =~ /ý$/
        )
    {
        $lemma =~ s/ý$/á/;
    }

    my $form = $morphoLM->best_form_of_lemma( $lemma, $tag_regex );
    return $form if $form;

    # try suffix only
    if ( $lemma =~ /^(\P{IsAlpha}+)(\p{IsAlpha}+)$/ ) {
        my $prefix       = $1;
        my $lemma_suffix = $2;
        my $form_suffix  = $morphoLM->best_form_of_lemma( $lemma_suffix, $tag_regex );
        if ($form_suffix) {
            $form_suffix->set_lemma( $prefix . $form_suffix->get_lemma() );
            $form_suffix->set_form( $prefix . $form_suffix->get_form() );
            return $form_suffix;
        }
    }

    # If there are no compatible forms in LM, try Hajic's morphology generator
    my ($form_info) = $generator->forms_of_lemma( $lemma, { tag_regex => "^$tag_regex" } );
    if ($form_info) {
        log_debug( "MORF: $lemma\t$tag_regex\t" . $form_info->get_form() . "\t" . $form_info->get_tag() . "\tttred " . $a_node->get_address() . " &", 1 );
    }
    return $form_info if $form_info;

    # (HACK) try capitalized lemma
    my $capitalized_lemma = ucfirst $lemma;
    $form = $morphoLM->best_form_of_lemma( $capitalized_lemma, $tag_regex );
    return $form if $form;

    ($form_info) = $generator->forms_of_lemma( $capitalized_lemma, { tag_regex => "^$tag_regex" } );
    return $form_info if $form_info;

    $form = _form_after_tag_relaxing( $lemma, $tag_regex, $partial_regexps_ref, $a_node );
    return $form if $form;

    # If there are no compatible forms from morphology analysis, return the lemma at least
    log_debug( "LEMM: $lemma\t$tag_regex\t$lemma\tttred " . $a_node->get_address() . " &", 1 );

    $lemma =~ s/(..t)-\d$/$1/;    # removing suffices distinguishing homonymous lemmas (stat-2)
    return Treex::Tool::LM::FormInfo->new( { form => $lemma, lemma => $lemma, tag => 'X@-------------', count => 0 } );
}

# relax regexp requirements: avoid pieces that cannot be satisfied for the given lemma anyway

sub _form_after_tag_relaxing {
    my ( $lemma, $tag_regex, $partial_regexps_ref, $a_node ) = @_;

    #    print "Trying relaxing\t tag = $tag_regex \t lemma = $lemma\n";
    #    print "Sentence: ".$a_node->get_bundle->get_attr('czech_target_sentence')."\n";

    my @all_possible_tags = grep {/./} map { $_->get_tag() } $generator->forms_of_lemma($lemma);

    #    print "Possible tags: ".join(" ",@all_possible_tags)."\n";

    if (@all_possible_tags) {

        my %allowed_value;
        foreach my $tag (@all_possible_tags) {
            if ( $tag =~ /$tag_regex/ ) {

                #print "QQQ: but $tag matches !\n";
            }
            my @values = split //, $tag;
            foreach my $category (@CATEGORIES) {
                $allowed_value{$category}{ ( shift @values ) || "" } = 1;    #!!! divny, to by nemelo byt potreba
            }
        }

        my @relaxed_cats;

        CAT:
        foreach my $category (@CATEGORIES) {
            my $partial_regexp = $partial_regexps_ref->{$category};
            foreach my $value ( keys %{ $allowed_value{$category} } ) {
                if ( $value =~ $partial_regexp ) {
                    next CAT;
                }
            }
            $partial_regexps_ref->{$category} = ".";
            push @relaxed_cats, $category;
        }

        if (@relaxed_cats) {
            my $old_regex = $tag_regex;
            $tag_regex = ( join q{}, map { $partial_regexps_ref->{$_} } @CATEGORIES ) . "[-1]";
            my $form = $morphoLM->best_form_of_lemma( $lemma, $tag_regex );
            if ($form) {
                log_debug(
                    "RELAXED\tid=" . $a_node->get_address() . "\t"
                        . "lemma=$lemma\t"
                        . "relaxed=" . join( "+", @relaxed_cats ) . "\t"
                        . "old_mask=$old_regex\t"
                        . "new_mask=$tag_regex\t"
                        . "new_form=$form\t"
                    , 1
                );
                return $form;
            }
        }
    }

    return;
}

sub _get_tag_regex {
    my $a_node = shift;
    my %morphcat;
    my ( $lemma, $id ) = $a_node->get_attrs( 'lemma', 'id' );

    # underspecified values will be allowed by regular expressions
    foreach my $category (@CATEGORIES) {
        $morphcat{$category} = $a_node->get_attr("morphcat/$category");
        if ( !defined $morphcat{$category} ) {
            log_warn("Morphcat '$category' undef with lemma=$lemma id=$id");
            $morphcat{$category} = '.';
        }
    }

    # jinak je ta podspecifikace moc divoka a povoli 'byla' misto 'byly'
    if ($morphcat{subpos} =~ /[sp]/
        and $morphcat{gender} eq 'F'
        and $morphcat{number} eq 'P'
        )
    {
        $morphcat{gender} = 'T';
    }
    else {
        if ( $morphcat{gender} eq 'N' ) {
            if ( $morphcat{number} eq 'P' ) {
                $morphcat{gender} =~ s/N/\[NHQXZ\-\]/;    # Q navic, jen pro neutrum *pluralu*, jinak podspecifikace dovoli nesmysly
            }
            else {
                $morphcat{gender} =~ s/N/\[NHXZ\-\]/;
            }
        }
        elsif ( $morphcat{gender} eq 'F' ) {
            if ( $morphcat{number} eq 'S' ) {
                $morphcat{gender} =~ s/F/\[FHQTX\-\]/;    # Q navic jen pro femininum *singularu*, pomlcka navic kvuli "odsuzuje"
            }
            else {
                $morphcat{gender} =~ s/F/\[FHTX\-\]/;     # pomlcka navic kvuli "odsuzuje"
            }
        }
        $morphcat{gender} =~ s/I/\[ITXYZ\-\]/;
        $morphcat{gender} =~ s/M/\[MXYZ\-\]/;

        $morphcat{number} =~ s/P/\[DPWX\-\]/;             # D - dual?
        $morphcat{number} =~ s/S/\[SWX\-\]/;
    }

    $morphcat{subpos} =~ s/A/\[AU\]/;

    $morphcat{case} =~ s/(\d)/\[${1}X\]/;

    $morphcat{possgender} =~ s/F/\[FX\]/;
    $morphcat{possgender} =~ s/M/\[MXZ\]/;
    $morphcat{possgender} =~ s/I/\[IXZ\]/;
    $morphcat{possgender} =~ s/N/\[NXZ\]/;

    $morphcat{possnumber} =~ s/([PS])/\[${1}X\]/;

    $morphcat{person} =~ s/(\d)/\[${1}X\-\]/;

    $morphcat{tense} =~ s/F/\[FX\]/;
    $morphcat{tense} =~ s/P/\[PHX\]/;
    $morphcat{tense} =~ s/R/\[RHX\]/;

    $morphcat{negation} =~ s/A/\[\-A\]/;          # nektera prislovce nejsou negovatelna
    $morphcat{grade}    =~ s/(\d)/\[\-${1}\]/;    # a nektera nejsou stupnovatelna

    # Hack for verb/adjective mess, e.g.
    # SEnglishA form=organized     tag=VBN
    # SEnglishT t_lemma=organize     sempos=v formeme=v:attr   is_passive=undef
    # TCzechT   t_lemma=organizovaný sempos=v formeme=adj:attr is_passive=undef
    # TCzechA   lemma=organizovaný morphcat/voice=A
    # Should there be sempos=adj ?
    $morphcat{voice} =~ s/A/\[A-\]/;

    my $tag_regex = join q{}, map { $morphcat{$_} } @CATEGORIES;

    # na konci nema byt cislo (nespisov. nebo arch).
    return ( $tag_regex . '[-1]', \%morphcat );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::GenerateWordforms

=item DESCRIPTION

This module generates word forms according to the given lemma and constraints
on morphological categories in each target side a-node.

Quite usually there is an underspecified tag, for example we do not know the gender
of a verb. If there are more Czech forms of the given lemma which are compatible
with the (underspecified) tag then the most frequent form is choosen.

Forms and their frequencies are taken from C<Treex::Tool::LM::MorphoLM>.
C<CzechMorpho> interface to Jan Hajic's morphology is now used only as a fallback
when there are no compatible forms in C<Treex::Tool::LM::MorphoLM>.

The resulting form and its corresponding tag are stored in the node attributes
C<form> and C<tag>.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

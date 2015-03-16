package Treex::Tool::Lexicon::Generation::CS;
use Moose;
use Treex::Core::Common;
use Ufal::MorphoDiTa;
use Treex::Tool::LM::FormInfo;
use Treex::Tool::Lexicon::CS::Prefixes;
use Treex::Core::Resource;

has dict_name => (is=>'ro', isa=>'Str', default=>'czech-morfflex-131112.dict');
has dict_path => (is=>'ro', isa=>'Str', lazy_build=>1);
has tool  => (is=>'ro', lazy_build=>1);

sub _build_dict_path {
    my ($self) = @_;
    return Treex::Core::Resource::require_file_from_share('data/models/morphodita/cs/'.$self->dict_name);
}

# tool can be shared by more instances (if the dictionary file is the same)
my %TOOL_FOR_PATH;
sub _build_tool {
    my ($self) = @_;
    my $path = $self->dict_path;
    my $tool = $TOOL_FOR_PATH{$path};
    return $tool if $tool;
    $tool = Ufal::MorphoDiTa::Morpho::load($path);
    $TOOL_FOR_PATH{$path} = $tool;
    return $tool;
}

# Shared global variables
my $lemmas_forms = Ufal::MorphoDiTa::TaggedLemmasForms->new();
my $tagged_lemmas = Ufal::MorphoDiTa::TaggedLemmas->new();

sub BUILD {
    my ($self) = @_;
    # The tool is lazy_build, so load it now
    $self->tool;
    return;
}

sub forms_of_lemma {
    my ( $self, $lemma, $arg_ref ) = @_;
    log_fatal('No lemma given to forms_of_lemma()') if !defined $lemma;

    my $tag_regex = $arg_ref->{tag_regex} || '.*';
    my $limit     = $arg_ref->{limit}     || 0;
    my $guess = defined $arg_ref->{guess} ? $arg_ref->{guess} : 1;

    # By default, if a lemma starts with a capital letter, return also capitalized form
    my $no_capitalization = $arg_ref->{no_capitalization} || 0;

    # MorphoDiTa's internal guesser does not seem to work for generation.
    # We use $tag_regex which is more poverful than MorphoDiTa's internal wildcard filtering.
    my $morphodita_guesser = 0;
    my $morphodita_wildcard = undef;

    # The main work
    $self->tool->generate($lemma, $morphodita_wildcard, $morphodita_guesser, $lemmas_forms);

    # Extract the generated forms from $lemmas_forms into Perl structure @forms
    my @forms = ();
    for (my $i = 0; $i < $lemmas_forms->size(); $i++) {
        my $lemma_forms = $lemmas_forms->get($i);
        my $pdt_lemma = $lemma_forms->{lemma};
        for (my $i = 0; $i < $lemma_forms->{forms}->size(); $i++) {
            my $form_object = $lemma_forms->{forms}->get($i);
            my $form_info = Treex::Tool::LM::FormInfo->new(
                {
                    form   => $form_object->{form},
                    lemma  => $pdt_lemma,
                    tag    => $form_object->{tag},
                    origin => $self->dict_name,
                }
            );
            push @forms, $form_info;
        }
    }

    # If no forms found, try our guesser
    if (!@forms){
        my ( $origin, $forms_tags ) = $self->_guess_forms($lemma);
        foreach my $form_tag ( split /\|/, ( $forms_tags || '' ) ) {
            my ( $form, $tag ) = split /\t/, $form_tag;
            my $form_info = Treex::Tool::LM::FormInfo->new(
                {
                    form   => $form,
                    lemma  => $lemma,
                    tag    => $tag,
                    origin => $origin
                }
            );
            push @forms, $form_info;
        }
    }

    # Prune @forms
    if ($tag_regex ne '.*'){
        $tag_regex = qr{$tag_regex};    #compile regex
        @forms = grep {$_->get_tag() =~ $tag_regex} @forms;
    }

    # Uppercase @forms
    if (!$no_capitalization){
        foreach my $fi (@forms){
            if ( $fi->get_lemma() =~ /^\p{IsUpper}/ ) {
                $fi->set_form( ucfirst $fi->get_form() );
            }
        }
    }

    # Sort @forms using a heuristic, so the more common forms go first.
    # For speed, we should do this only when the user asks for it,
    # but the legacy code does not use limit.
    @forms = map {$_->[0]->set_count($_->[1]); $_->[0]}
             sort {$b->[1] <=> $a->[1]}
             map {[$_, _score_tag($_)]} @forms;
        
    # If asked to return only the N-best forms, delete the rest.    
    splice @forms, $limit if $limit;

    log_debug( "FORMS_OF_LEMMA RETURN\t" . join( "\t", @forms ), 1 );
    return @forms;
}

# This implementation is a heap of hacks.
# TODO: load corpus-based tag frequencies (and use these rules only as a fallback if at all).
# Even better would be to integrate this into MorphoDiTa.
sub _score_tag {
    my ($form_info) = @_;
    my $tag = $form_info->get_tag();
    my $lemma = $form_info->get_lemma();
    my $score = 0;
    $score -= 100 if $tag !~ /-$/; # non-official
    $score -= 50 if $tag =~ /^.[CYedhjkmqst]/; # strange subpos (transgressive etc.)
    $score -= 50 if $tag =~ /^Vp.{5}2/; # enclitics with verbs ("udělals")
    $score -= 20 if $tag =~ /^Vi/; # imperative
    $score -= 20 if $tag =~ /^...D/; # dual
    $score -= 20 if $tag =~ /^.{9}[23]/; # comparative & superlative
    $score -= 10 if $tag =~ /^.{10}N/; # negative
    $score -= 5 if  $tag =~ /^...P/; # plural
    $score -= 2 if  $tag =~ /^.{4}[3567]/; # case I don't like:-)
    #$score -= 1 if  $tag ne $lemma; # to distinguish e.g. "exkluzivní" and "exklusivní" which have the same tag and lemma
    return $score;
}

# Note that this actually returns a random form (because the forms are not sorted).
# This method makes it just easy to fallback from Treex::Tool::LM::MorphoLM to this class.
sub best_form_of_lemma {
    my ( $self, $lemma, $tag_regex ) = @_;
    my ($form_info) = $self->forms_of_lemma( $lemma, { tag_regex => $tag_regex, limit=>1 } );
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

sub analyze_form {
    my ($self, $form, $use_guesser) = @_;
    $use_guesser = $use_guesser ? $Ufal::MorphoDiTa::Morpho::GUESSER : $Ufal::MorphoDiTa::Morpho::NO_GUESSER;
    $self->tool->analyze($form, $use_guesser, $tagged_lemmas);
    my @analyzes;
    for my $i (0 .. $tagged_lemmas->size()-1){
          my $tagged_lemma = $tagged_lemmas->get($i);
          push @analyzes, {tag=>$tagged_lemma->{tag}, lemma=>$tagged_lemma->{lemma}};
    }
    return @analyzes;
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::Generation::CS

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::Generation::CS;
 my $generator = Treex::Tool::Lexicon::Generation::CS->new();
 
 ### SYNTHESIS
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
 
 ### ANALYZIS
 my @analyzes = $generator->analyze_form('stane');
 my $use_guesser = 1;
 foreach my $an (@analyzes, $use_guesser) {
     print "$an->{tag} $an->{lemma}\n";
 }

=head1 DESCRIPTION

Wrapper for state-of-the-art Czech morphological analyzer and synthesizer MorphoDiTa
by Milan Straka and Jana Straková.

=head1 TODO

rename this module, as it now offers not only synthesis, but also analyzis

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

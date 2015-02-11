#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';

use Treex::Tool::LM::MorphoLM;
use Treex::Tool::LM::FormInfo;

# load default model file
my $morphoLM = Treex::Tool::LM::MorphoLM->new();

print "Lemma 'moci': form tag count\n";
my @forms = $morphoLM->forms_of_lemma('moci');
foreach my $form_info (@forms) {
    print join( "\t", $form_info->get_form(), $form_info->get_tag(), $form_info->get_count() ), "\n";
}

print "\nMost frequent past participle of 'moci' is: "
    , $morphoLM->best_form_of_lemma( 'moci', '^Vp' )
    , "\n\n";

print "Past participles of 'moci'\n";
@forms = $morphoLM->forms_of_lemma( 'moci', { tag_regex => '^Vp' } );
foreach my $form_info (@forms) {
    print $form_info->to_string(), "\n";
}

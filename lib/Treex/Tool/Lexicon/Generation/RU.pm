package Treex::Tool::Lexicon::Generation::RU;

use Treex::Core::Common;
use utf8;
use LanguageModel::FormInfo;
use Class::Std;

use PerlIO::gzip;

use Treex::Core::Resource qw(require_file_from_share);
my $freq_file = 'data/models/morpho_analysis/ru/extracted_freq.bigger.tsv.gz';
my $freq_file_path = require_file_from_share( $freq_file, 'Treex::Tool::Lexicon::Generation::RU' );

my %lemma_tag_form;

open my $MORPHO,'<:gzip',
    $freq_file_path,
    or die $!;

binmode($MORPHO,":utf8");

while (<$MORPHO>) {
    chomp;
    s/^ +//;
    my ($count,$form,$lemma,$tag) = split;
    if ($count and $lemma and $form and $tag) {  #TODO: there should be no empty values !
        $lemma = lc($lemma);
        my $formtag = "$form|$tag";
        $lemma_tag_form{$lemma}{$formtag} += $count;
     }
}


sub forms_of_lemma {

    my ( $self, $lemma, $arg_ref ) = @_;

    $lemma = lc($lemma);
    log_fatal('lemma je '.$lemma) if ($lemma eq '@card@');

    log_fatal('No lemma given to forms_of_lemma()') if !defined $lemma;

    my $tag_regex = $arg_ref->{'tag_regex'} || '.*';
    my $limit     = $arg_ref->{'limit'}     || 0;
    my $guess = defined $arg_ref->{'guess'} ? $arg_ref->{'guess'} : 1;


    my @all_forms = ();

    my $forms_tags = keys %{$lemma_tag_form{$lemma} || {}};

    if ($lemma_tag_form{$lemma}) {
        foreach my $form_tag ( sort {$lemma_tag_form{$lemma}{$b} <=> $lemma_tag_form{$lemma}{$a}}
                                   keys %{$lemma_tag_form{$lemma} } ) {


            my ( $form, $tag ) = split /\|/,$form_tag;
            
            #replacing incorrect latin c to cyrillic "es" ( U+0063 -> U+0441 )
            $form =~ s/\x{0063}/\x{0441}/g;

            my $form_info = LanguageModel::FormInfo->new(
                {
                    form   => $form,
                    lemma  => $lemma,
                    tag    => $tag,
                    origin => 'syntagrus',
                    count => $lemma_tag_form{$lemma}{$form_tag},
                }
            );

            push @all_forms, $form_info;
        }
    }

    $tag_regex = qr{$tag_regex};    #compile regex
    my $found = 0;
    my @forms;
    foreach my $fi (@all_forms) {
        next if $fi->get_tag() !~ $tag_regex;
        push @forms, $fi;
        last if $limit and ( ++$found >= $limit );
    }

    return @forms;

}

sub best_form_of_lemma {
    my ( $self, $lemma, $tag_regex ) = @_;
    my ($form_info) = $self->forms_of_lemma( $lemma, { tag_regex => $tag_regex, limit => 1 } );
    return $form_info ?  $form_info : undef;
}


1;

__END__

=head1 NAME

Treex::Tool::Lexicon::Generation::RU

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::Generation::RU;
 my $generator = Treex::Tool::Lexicon::Generation::RU->new();
 
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


Morphological generation for Russian, based on form-lemma-tag tuples extracted
from Syntagrus


=cut

# Copyright 2012 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

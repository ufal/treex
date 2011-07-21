package Treex::Tool::Lexicon::CS::Reflexivity;

use strict;
use warnings;
use utf8;

my $tantum_si_regexp = "libovat|oblibovat|oblíbit|postesknout|postýskat|
postýskávat|postěžovat|povšimnout|stěžovat|stýskat|stesknout|stýsknout|
stýskávat|šplhnout|troufat|troufnout|všímat|všimnout|zapamatovávat|zapamatovat|
lehnout|odpočnout|odpočinout|pochutnat|pochutnávat|sednout|uvědomit|uvědomovat|
vzpomenout|vzpomínat|zasloužit|dobírat|hovět|lebedit|osvojit|pamatovat|pospíšit|
prohlížet|prohlédnout|popovídat";

my $tantum_se_regexp = "bát|blížit|dařit|dařívat|dít|dívat|divit|dohadovat|
dochovávat|dochovat|domáhat|domoci|domnívat|dostavovat|dostavit|dotýkat|
dotknout|dovolávat|dovolat|dozvídat|dovídat|dozvědět|dovědět|dožadovat|
hemžit|hroutit|chlubit|chlubívat|lepšit|lesknout|líbit|linout|loučit|loučívat|
modlit|modlívat|najíst|napít|narodit|naskytat|naskýtat|naskytovat|naskytnout|
obávat|ocitat|ocítat|ocitnout|octnout|odhodlávat|odhodlat|odmlčovat|odmlčet|
odvažovat|odvážit|ohlížet|ohlédnout|ohrazovat|ohradit|otázat|ozývat|ozvat|
podařit|podílet|podívat|podivovat|podivit|podobat|pohádat|pochlubit|poprat|
postarat|povést|přiházet|přihodit|přít|ptát|ptávat|pyšnit|pyšnívat|radovat|
rozhlížet|rozhlédnout|rozpadávat|rozpadat|rozpadnout|rozpadat|rozplývat|
rozplynout|rozrůstat|rozrůst|řítit|setkávat|setkat|shodovat|shodnout|smát|
smávat|snažit|snažívat|specializovat|spiknout|spokojovat|spokojit|starat|
stávat|stydět|stýkat|stýkávat|tázat|toulat|toulávat|tvářit|týkat|účastnit|
udát|ucházet|uchylovat|uchýlit|usmívat|usmát|usnášet|usnést|ušklebovat|
ušklibovat|ušklíbat|ušklíbnout|utkávat|vadit|vadívat|vloupávat|vlupovat|
vloupat|vydařit|vyhýbat|vyhnout|vyhrkat|vyptávat|vyptat|vyskytovat|vyskytnout|
vyspat|vystříhat|vyvarovávat|vyvarovat|vzpamatovávat|vzpamatovat|zabývat|
zadívat|zahledět|zalíbit|zamilovat|zamračit|zasmát|zdařit|zdát|zdávat|zdráhat|
zdráhávat|zeptat|zříkat|zříci|zřeknout|zřítit|zúčastňovat|zúčastnit|plížit|
připlížit|hrbit|shrbit|krčit|klikatit|vynořit|skrčit|rouhat|potulovat|
řítit|rozednívat";

sub fix_reflexivity {
    my $lemma = shift;

    if ($lemma =~ /^($tantum_si_regexp)$/sxm) {
        return $lemma."_si";
    }
    elsif ($lemma =~ /^($tantum_se_regexp)$/sxm) {
        return $lemma."_se";
    }
    else {
        return $lemma;
    }
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::Lexicon::CS::Reflexivity

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::CS::Reflexivity;
 
 foreach my $lemma (qw(chodit zeptat troufat)) {
     print Treex::Tool::Lexicon::CS::Reflexivity::fix_reflexivity($lemma)."\n";
 }

=head1 DESCRIPTION

=over 4

=item my $corrected_tlemma = Treex::Tool::Lexicon::CS::Reflexivity::fix_reflexivity($tlemma);

If the given Czech verb lemma is reflexivum tantum,
then the reflexive suffix "_si" or "_se" is added to the lemma.
Based on a list of reflexives extracted from VALLEX 2.5.

=back

=cut

=head1 COPYRIGHT

Copyright 2009 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README



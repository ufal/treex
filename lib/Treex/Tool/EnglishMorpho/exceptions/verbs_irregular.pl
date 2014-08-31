#!/usr/bin/env perl
use strict;
use warnings;

#based on http://en.wikipedia.org/wiki/List_of_English_irregular_verbs
#and      http://www.englishpage.com/irregularverbs/irregularverbs2.html

=for comment

List of English irregular verbs in perl hash

Format:
ps means past simple or preterite
pp means past participle
com means comment

reg=>1 means that most common are regular forms of this verb
reg=>2 means that regular forms of this verb are possible, but not the most common

We define a verb as a regular if
 $base =~ /[^ey]$/ && $ps eq $base.'ed' && $pp eq $base.'ed'
or
 $base =~ /e$/ && $ps eq $base.'d' && $pp eq $base.'d'

So f.e. bet/betted/betted is NOT regular.

=cut

#<<< perltidy off (it would break my columns)
my %irregular_verbs = (
'abide'   => {ps=>'abode',       pp=>'abidden',     reg=>1},
'arise'   => {ps=>'arose',       pp=>'arisen'},
'awake'   => {ps=>'awoke',       pp=>'awoken'},
'be'      => {ps=>'was|were',    pp=>'been',                             com=>'"was" singular, "were" plural'},
'bear'    => {ps=>'bore',        pp=>'born|borne',  pref=>'for|over|un', com=>'"born" only for passive constructions (I was born in Chicago), "borne" for all other uses, including active constructions (She has borne both her children at home)'},
'beat'    => {ps=>'beat',        pp=>'beaten|beat', pref=>'brow'},
'beget'   => {ps=>'begot|begat', pp=>'begotten'},
'begin'   => {ps=>'began',       pp=>'begun'},
'bend'    => {ps=>'bent',        pp=>'bent',        reg=>2,  pref=>'un'},
'beseech' => {ps=>'besought',    pp=>'besought',    reg=>2},
'bet'     => {ps=>'bet|betted',  pp=>'bet|betted'},
'bid'     => {ps=>'bid|bade',    pp=>'bid|bidden',  pref=>'out|over|re|under', com=>'"bid/bid/bid" in cards, auctions, etc., "bid/bade/bidden" meaning to request or say'},
'bide'    => {ps=>'bode',        pp=>'bidden',      reg=>1},
'bind'    => {ps=>'bound',       pp=>'bound',       pref=>'un'},
'bite'    => {ps=>'bit',         pp=>'bitten',      pref=>'frost'},
'bleed'   => {ps=>'bled',        pp=>'bled'},
'blow'    => {ps=>'blew',        pp=>'blown'},
'break'   => {ps=>'broke',       pp=>'broken'},
'breed'   => {ps=>'bred',        pp=>'bred',        pref=>'in|inter|over'},
'bring'   => {ps=>'brought',     pp=>'brought'},
'build'   => {ps=>'built',       pp=>'built',       pref=>'jerry-|over|re|un'},
'burn'    => {ps=>'burnt',       pp=>'burnt',       reg=>2, pref=>'sun'},
'burst'   => {ps=>'burst',       pp=>'burst',       reg=>2},
'bust'    => {ps=>'bust',        pp=>'bust',        reg=>1},
'buy'     => {ps=>'bought',      pp=>'bought',      pref=>'over|under'},
'cast'    => {ps=>'cast',        pp=>'cast',        pref=>'broad|for|fore|mis|over|re|rebroad|rough|sand-|tele|type'},
'catch'   => {ps=>'caught',      pp=>'caught'},
'choose'  => {ps=>'chose',       pp=>'chosen'},
'cleave'  => {ps=>'clove|cleft', pp=>'cloven|cleft',reg=>2,            com=>'irregular forms means "split apart", regular means "adhere/cling to"'},
'cling'   => {ps=>'clung',       pp=>'clung'},
'clothe'  => {ps=>'clad',        pp=>'clad',        reg=>1, pref=>'un', com=>'although otherwise archaic, "clad" is still often used as an adjective to mean "dressed in."'},
'come'    => {ps=>'came',        pp=>'come',        pref=>'be|over'},
'cost'    => {ps=>'cost',        pp=>'cost'},
'creep'   => {ps=>'crept',       pp=>'crept'},
'cut'     => {ps=>'cut',         pp=>'cut',         pref=>'inter|over|re|under'},
'deal'    => {ps=>'dealt',       pp=>'dealt',       pref=>'mis'},
'dig'     => {ps=>'dug',         pp=>'dug'},
'dive'    => {ps=>'dove',        pp=>'dived',       reg=>1,       com=>'irregular only in Am.'},
'do'      => {ps=>'did',         pp=>'done',        pref=>'for|mis|out|over|re|un'},
'drag'    => {ps=>'drug|drugged',pp=>'drug|drugged'},
'draw'    => {ps=>'drew',        pp=>'drawn',       pref=>'out|over|re|un|with'},
'dream'   => {ps=>'dreamt',      pp=>'dreamt',      reg=>1, pref=>'day'},
'drink'   => {ps=>'drank|drunk', pp=>'drank|drunk|drunken', pref=>'out|over'},
'drive'   => {ps=>'drove',       pp=>'driven',      pref=>'out|test-'},
'dwell'   => {ps=>'dwelt',       pp=>'dwelt',       reg=>2},
'eat'     => {ps=>'ate',         pp=>'eaten',       pref=>'over'},
'fall'    => {ps=>'fell',        pp=>'fallen',      pref=>'be'},
'feed'    => {ps=>'fed',         pp=>'fed',         pref=>'over|under'},
'feel'    => {ps=>'felt',        pp=>'felt'},
'fight'   => {ps=>'fought',      pp=>'fought',      pref=>'out'},
'find'    => {ps=>'found',       pp=>'found'},
'fit'     => {ps=>'fit|fitted',  pp=>'fit|fitted',  pref=>'re|retro'},
'flee'    => {ps=>'fled',        pp=>'fled'},
'fling'   => {ps=>'flung',       pp=>'flung'},
'fly'     => {ps=>'flew',        pp=>'flown',      pref=>'out|test-'},
'forbid'  => {ps=>'forbad|forbade|forbid', pp=>'forbid|forbidden'}, #bad is NOT VBD of bid, so forbid cannot be "prefixed" to bid
'forsake' => {ps=>'forsook',     pp=>'forsaken'},
'fraught' => {ps=>'fraught',     pp=>'fraught'},
'freeze'  => {ps=>'froze',       pp=>'frozen',      pref=>'quick-|un'},
'get'     => {ps=>'got',         pp=>'gotten|got',  pref=>'for', com=>'Am./Br.',},
'gird'    => {ps=>'girt',        pp=>'girt',        reg=>2},
'give'    => {ps=>'gave',        pp=>'given',       pref=>'for'},
'go'      => {ps=>'went',        pp=>'gone',        pref=>'for|fore|under', com=>'forgo and forego are synonyms'},
'grind'   => {ps=>'ground|grinded', pp=>'ground',   pref=>'re'},
'grow'    => {ps=>'grew',        pp=>'grown',       pref=>'out|over|re'},
'hang'    => {ps=>'hung',        pp=>'hung',        reg=>2, pref=>'over|re|un'},
'have'    => {ps=>'had',         pp=>'had'},
'hear'    => {ps=>'heard',       pp=>'heard',       pref=>'mis|over|re'},
'hew'     => {ps=>'hew',         pp=>'hewn',        reg=>2},
'hide'    => {ps=>'hid',         pp=>'hidden|hid',  pref=>'un'},
'hit'     => {ps=>'hit',         pp=>'hit'},
'hold'    => {ps=>'held',        pp=>'held',        pref=>'be|un|up|with'},
'hurt'    => {ps=>'hurt',        pp=>'hurt'},
'keep'    => {ps=>'kept',        pp=>'kept'},
'kneel'   => {ps=>'knelt',       pp=>'knelt',        reg=>2},
'knit'    => {ps=>'knit|knitted',pp=>'knit|knitted', pref=>'re|un'},
'know'    => {ps=>'knew',        pp=>'known',        pref=>'fore'},
'lade'    => {ps=>'laded',       pp=>'laden',        reg=>2, pref=>'un'},
'lay'     => {ps=>'laid',        pp=>'laid',         pref=>'in|inter|mis|over|re|re-|un|under|way'},
'lead'    => {ps=>'led',         pp=>'led',          pref=>'mis'},
'lean'    => {ps=>'leant',       pp=>'leant',        reg=>1},
'leap'    => {ps=>'leapt',       pp=>'leapt',        reg=>2, pref=>'over'},
'learn'   => {ps=>'learnt',      pp=>'learnt',       reg=>2, pref=>'mis|re|un'},
'leave'   => {ps=>'left',        pp=>'left'},
'lend'    => {ps=>'lent',        pp=>'lent'},
'let'     => {ps=>'let',         pp=>'let',          pref=>'sub|under'},
'lie'     => {ps=>'lay',         pp=>'lain',         reg=>2, pref=>'over|under', com=>'lie/lay/lain irregular is "opposite to sit", lie/lied/lied regular is "opposite to tell truth"'},
'light'   => {ps=>'lit',         pp=>'lit',          reg=>2, pref=>'re'},
'lose'    => {ps=>'lost',        pp=>'lost'},
'make'    => {ps=>'made',        pp=>'made',         pref=>'re|un'},
'mean'    => {ps=>'meant',       pp=>'meant'},
'meet'    => {ps=>'met',         pp=>'met'},
'mow'     => {ps=>'mowed',       pp=>'mown',         reg=>1},
'pay'     => {ps=>'paid',        pp=>'paid',         pref=>'over|pre|re'},
'plead'   => {ps=>'pled',        pp=>'pled',         reg=>1},
'prove'   => {ps=>'proved',      pp=>'proven',       reg=>1, pref=>'dis'},
'put'     => {ps=>'put',         pp=>'put',          pref=>'in'},
'quit'    => {ps=>'quit|quitted',pp=>'quit|quitted'},
'read'    => {ps=>'read',        pp=>'read',         pref=>'lip|lip-|mis|proof|re|sight-'},
'reave'   => {ps=>'reft',        pp=>'reft',         reg=>1, pref=>'be'},
'rend'    => {ps=>'rent',        pp=>'rent'},
'rid'     => {ps=>'rid|ridded',  pp=>'rid|ridden|ridded'},
'ride'    => {ps=>'rode',        pp=>'ridden',       pref=>'out|over'},
'ring'    => {ps=>'rang',        pp=>'rung'},
'rise'    => {ps=>'rose',        pp=>'risen'},
'rive'    => {ps=>'rove',        pp=>'riven',        reg=>2},
'run'     => {ps=>'ran',         pp=>'run',          pref=>'fore|out|over|re|under'},
'saw'     => {ps=>'sawed',       pp=>'sawn',         reg=>1},
'say'     => {ps=>'said',        pp=>'said',         pref=>'gain|mis|un'},
'see'     => {ps=>'saw',         pp=>'seen',         pref=>'fore|over'},
'seek'    => {ps=>'sought',      pp=>'sought'},
'sell'    => {ps=>'sold',        pp=>'sold',         pref=>'out|over|pre|re|under'},
'send'    => {ps=>'sent',        pp=>'sent',         pref=>'mis|re'},
'set'     => {ps=>'set',         pp=>'set',          pref=>'be|in|inter|mis|off|over|pre|re|type|up'},
'sew'     => {ps=>'sewed',       pp=>'sewn',         reg=>1, pref=>'over|re|un'},
'shake'   => {ps=>'shook',       pp=>'shaken'},
'shape'   => {ps=>'shaped',      pp=>'shapen',       reg=>1, pref=>'mis'},
'shave'   => {ps=>'shove',       pp=>'shaven',       reg=>1},
'shear'   => {ps=>'shore',       pp=>'shorn',        reg=>2},
'shed'    => {ps=>'shed|shedded',pp=>'shed|shedded'},
'shine'   => {ps=>'shone',       pp=>'shone',        reg=>1, pref=>'out'},
'shit'    => {ps=>'shit|shat|shitted', pp=>'shit|shat|shitted'},
'shoe'    => {ps=>'shoed|shod',  pp=>'shoed|shod|shodden'},
'shoot'   => {ps=>'shot',        pp=>'shot',         pref=>'out|over|under'},
'show'    => {ps=>'showed|shew', pp=>'shown|showed', pref=>'fore'},
'shrink'  => {ps=>'shrank|shrunk', pp=>'shrunk|shrunken', pref=>'pre'},
'shut'    => {ps=>'shut',        pp=>'shut'},
'sing'    => {ps=>'sang',        pp=>'sung',         pref=>'out'},
'sink'    => {ps=>'sank|sunk',   pp=>'sunk|sunken'},
'sit'     => {ps=>'sat',         pp=>'sat',          pref=>'out'},
'slay'    => {ps=>'slew',        pp=>'slain',        reg=>2},
'sleep'   => {ps=>'slept',       pp=>'slept',        pref=>'out|over'},
'slide'   => {ps=>'slid',        pp=>'slid|slidden', pref=>'back'},
'sling'   => {ps=>'slung|slang', pp=>'slung',        pref=>'un'},
'slink'   => {ps=>'slunk',       pp=>'slunk'},
'slit'    => {ps=>'slit',        pp=>'slit'},
'smell'   => {ps=>'smelt',       pp=>'smelt',        reg=>1},
'smite'   => {ps=>'smote|smit',  pp=>'smitten'},
'sneak'   => {ps=>'snuck',       pp=>'snuck',        reg=>1},
'sow'     => {ps=>'sew',         pp=>'sown',         reg=>1, pref=>'over'},
'speak'   => {ps=>'spoke',       pp=>'spoken',       pref=>'fore|mis|out|over'},
'speed'   => {ps=>'sped',        pp=>'sped',         reg=>2},
'spell'   => {ps=>'spelt',       pp=>'spelt',        reg=>1, pref=>'mis'},
'spend'   => {ps=>'spent',       pp=>'spent',        pref=>'mis|out|over|under'},
'spill'   => {ps=>'spilt',       pp=>'spilt',        reg=>1, pref=>'over'},
'spin'    => {ps=>'span|spun',   pp=>'spun',         pref=>'over|un'},
'spit'    => {ps=>'spit|spat',   pp=>'spit'},
'split'   => {ps=>'split',       pp=>'split'},
'spoil'   => {ps=>'spoilt',      pp=>'spoilt',       reg=>1},
'spread'  => {ps=>'spread',      pp=>'spread',       pref=>'over'},
'spring'  => {ps=>'sprang|sprung', pp=>'sprung',     pref=>'over'},
'stand'   => {ps=>'stood',       pp=>'stood',        pref=>'misunder|over|under|with'},
'steal'   => {ps=>'stole',       pp=>'stolen'},
'stick'   => {ps=>'stuck',       pp=>'stuck',        pref=>'un'},
'sting'   => {ps=>'stung',       pp=>'stung'},
'stink'   => {ps=>'stank|stunk', pp=>'stunk'},
'strew'   => {ps=>'strew',       pp=>'strewn',       reg=>2, pref=>'over'},
'stride'  => {ps=>'strode',      pp=>'stridden',     reg=>2, pref=>'over'},
'strike'  => {ps=>'struck',      pp=>'struck|stricken',      pref=>'over'},
'string'  => {ps=>'strung|strang', pp=>'strung',     pref=>'un'},
'strive'  => {ps=>'strove',      pp=>'striven',      reg=>2},
'swear'   => {ps=>'swore',       pp=>'sworn',        pref=>'for|mis|out|un'},
'sweep'   => {ps=>'swept',       pp=>'swept'},
'swell'   => {ps=>'swoll',       pp=>'swollen',      reg=>1},
'swim'    => {ps=>'swam',        pp=>'swum|swam',    pref=>'out'},
'swing'   => {ps=>'swung|swang', pp=>'swung'},
'take'    => {ps=>'took',        pp=>'taken',        pref=>'mis|over|par|re|under'},
'teach'   => {ps=>'taught',      pp=>'taught',       pref=>'mis|re|un'},
'tear'    => {ps=>'tore',        pp=>'torn'},
'tell'    => {ps=>'told',        pp=>'told',         pref=>'fore|re'},
'think'   => {ps=>'thought',     pp=>'thought',      pref=>'out|over|re|un'},
'thrive'  => {ps=>'throve',      pp=>'thriven',      reg=>1},
'throw'   => {ps=>'threw',       pp=>'thrown',       pref=>'out|over'},
'thrust'  => {ps=>'thrust',      pp=>'thrust',       reg=>2, pref=>'under'},
'tread'   => {ps=>'trod',        pp=>'trodden|trod'},
'unreeve' => {ps=>'unrove',      pp=>'unrove',       reg=>1},
'vex'     => {ps=>'vext',        pp=>'vext',         reg=>1},
'wake'    => {ps=>'woke',        pp=>'woken',        reg=>2, pref=>'re'},
'wear'    => {ps=>'wore',        pp=>'worn',         pref=>'mis|over'},
'weave'   => {ps=>'weaved|wove|weft', pp=>'woven|weft', reg=>2, pref=>'in|inter|re|un'},
'wed'     => {ps=>'wed|wedded',  pp=>'wed|wedded',   pref=>'mis'},
'weep'    => {ps=>'wept',        pp=>'wept'},
'wet'     => {ps=>'wet|wetted',  pp=>'wet|wetted',   pref=>'re'},
'win'     => {ps=>'won',         pp=>'won',          pref=>'re'},
'wind'    => {ps=>'wound',       pp=>'wound',        pref=>'inter|over|re|un'},
'work'    => {ps=>'wrought',     pp=>'wrought',      reg=>1, com=>'wrought is archaic'},
'wring'   => {ps=>'wrung',       pp=>'wrung'},
'write'   => {ps=>'wrote',       pp=>'written',      pref=>'hand|mis|out|over|re|un|type|under'},
);
#>>> perltidy on
#
sub print_dump() {
    while ( my ( $base, $forms ) = each %irregular_verbs ) {
        foreach my $pref ( '', split( '\|', $forms->{pref} || '' ) ) {
            print "$pref$base\t$pref" . $forms->{ps} . "\t$pref" . $forms->{pp};
            print "\tregular=" . $forms->{reg} if $forms->{reg};
            print "\tcomment=" . $forms->{com} if $forms->{com};
            print "\n";
        }
    }
    return;
}

sub analyze() {
    while ( my ( $base, $forms ) = each %irregular_verbs ) {
        foreach my $pref ( '', split( '\|', $forms->{pref} || '' ) ) {
            foreach ( split '\|', $forms->{ps} ) { print "$pref$_\tVBD\t$pref$base\n"; }
            foreach ( split '\|', $forms->{pp} ) { print "$pref$_\tVBN\t$pref$base\n"; }
        }
    }
    return;
}

sub all_possible {
    my $ps_or_pp = shift;
    while ( my ( $base, $forms ) = each %irregular_verbs ) {
        foreach my $pref ( '', split( '\|', $forms->{pref} || '' ) ) {
            foreach ( split '\|', $forms->{$ps_or_pp} ) { print "$pref$_\n"; }
        }
    }
    return;
}

if    ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-d' ) { print_dump(); }
elsif ( $ARGV[0] =~ /^--?preterite$/ )  { all_possible('ps'); }
elsif ( $ARGV[0] =~ /^--?participle$/ ) { all_possible('pp'); }
else                                    { die "Invalid usage: use option -a, -d, --preterite or --participle\n"; }

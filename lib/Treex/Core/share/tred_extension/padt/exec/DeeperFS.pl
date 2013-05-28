#!/usr/bin/perl -w ###################################################################### 2006/03/21
#
# DeeperFS.pl ########################################################################## Otakar Smrz

# $Id: DeeperFS.pl 4948 2012-10-16 22:12:17Z smrz $

use strict;

our $VERSION = do { q $Revision: 4948 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };

BEGIN {

    our $libDir = `btred --lib`;

    chomp $libDir;

    eval "use lib '$libDir', '$libDir/libs/fslib', '$libDir/libs/pml-base'";
}

use Treex::PML 1.6;


our $decode = "utf8";

our $encode = "utf8";


our ($source, $target, $file, $FStime);


# ##################################################################################################
#
# ##################################################################################################


@ARGV = glob join " ", @ARGV;


foreach $file (@ARGV) {

    $FStime = gmtime;

    $target = Treex::PML::Factory->createDocument({define_target_format()});

    $source = Treex::PML::Factory->createDocumentFromFile($file,{'encoding' => $decode});

    process_source();

    $file =~ s/(?:\.syntax)?\.fs$//;

    $target->writeFile($file . '.deeper.fs');
}


sub process_source {

    my $para_id = 0;

    foreach my $tree ($source->trees()) {

        my $para = $target->FS()->clone_subtree($tree);

        my $root = $target->insert_tree($para, $para_id++);

        $root->{'y_comment'} = $root->{'comment'};
        $root->{'comment'} = "$FStime [DeeperFS.pl $VERSION]";

        $root->{'ord'} = 0;

        $root->{'func'} = 'SENT';

        my $node = $root;

        while ($node = $node->following()) {

            $node->{'func'} = '???';

            $node->{'y_ord'} = $node->{'ord'};
            $node->{'y_parent'} = $node->parent()->{'ord'};
        }

        foreach $node ($root->descendants()) {

            if ($node->{'afun'} =~ /^Aux/) {

                $node->{'hide'} = 'hide';

                if (my @children = $node->children()) {

                    foreach my $child (reverse $node->children()) {

                        $child = $child->cut();

                        $child->paste_on($node->parent(), 'ord');
                    }

                    $node = $node->cut();

                    $node->paste_on($children[0], 'ord');
                }
            }
        }
    }
}


sub define_target_format {

    return (

        'FS'        => Treex::PML::Factory->createFSFormat([

            '@P form',
            '@P afun',
            '@O afun',
            '@L afun|Pred|Pnom|PredE|PredC|PredM|PredP|Sb|Obj|Adv|Atr|Atv|ExD|Coord|Apos|Ante|AuxS' .
                   '|AuxC|AuxP|AuxE|AuxM|AuxY|AuxG|AuxK|ObjAtr|AtrObj|AdvAtr|AtrAdv|AtrAtr|???',
            '@P lemma',
            '@P tag',
            '@P origf',
            '@V origf',
            '@N ord',
            '@P afunaux',
            '@P tagauto',
            '@P lemauto',
            '@P parallel',
            '@L parallel|Co|Ap',
            '@P paren',
            '@L paren|Pa',
            '@P arabfa',
            '@L arabfa|Ca|Exp|Fi',
            '@P arabspec',
            '@L arabspec|Ref|Msd',
            '@P arabclause',
            '@L arabclause|Pred|Pnom|PredE|PredC|PredM|PredP',
            '@P comment',
            '@P docid',
            '@P1 warning',
            '@P3 err1',
            '@P3 err2',
            '@P reserve1',
            '@P reserve2',
            '@P reserve3',
            '@P reserve4',
            '@P reserve5',
            '@P x_id_ord',
            '@P x_input',
            '@P x_lookup',
            '@P x_morph',
            '@P x_gloss',
            '@P x_comment',

            '@H hide',
            '@P y_ord',
            '@P y_parent',
            '@P y_comment',
            '@P context',
            '@L context|---|B|N|C|???',

            '@P gender',
            '@L gender|---|ANIM|INAN|FEM|NEUT|NA|???',
            '@P number',
            '@L number|---|SG|PL|NA|???',
            '@P degcmp',
            '@L degcmp|---|POS|COMP|SUP|NA|???',
            '@P tense',
            '@L tense|---|SIM|ANT|POST|NA|???',
            '@P aspect',
            '@L aspect|---|PROC|CPL|RES|NA|???',
            '@P iterativeness',
            '@L iterativeness|---|IT1|IT0|NA|???',
            '@P verbmod',
            '@L verbmod|---|IND|IMP|CDN|NA|???',
            '@P deontmod',
            '@L deontmod|---|DECL|DEB|HRT|VOL|POSS|PERM|FAC|NA|???',
            '@P sentmod',
            '@L sentmod|---|ENUNC|EXCL|DESID|IMPER|INTER|NA|???',
            '@P tfa',
            '@L tfa|---|T|F|C|NA|???',
            '@P func',
            '@L func|---|ACT|PAT|ADDR|EFF|ORIG|ACMP|ADVS|AIM|APP|APPS|ATT|BEN|CAUS|CNCS|COMPL|COND|CONJ|CONFR|CPR|CRIT|CSQ|CTERF|DENOM|DES|DIFF|DIR1|DIR2|DIR3|DISJ|DPHR|ETHD|EXT|EV|FPHR|GRAD|HER|ID|INTF|INTT|LOC|MANN|MAT|MEANS|MOD|NA|NORM|OPER|PAR|PARTL|PN|PREC|PRED|REAS|REG|RESL|RESTR|RHEM|RSTR|SUBS|TFHL|TFRWH|THL|THO|TOWH|TPAR|TSIN|TTILL|TWHEN|VOC|VOCAT|SENT|???',
            '@P gram',
            '@L gram|---|0|GNEG|DISTR|APPX|GPART|GMULT|VCT|PNREL|DFR|BEF|AFT|JBEF|INTV|WOUT|AGST|MORE|LESS|MINCL|LINCL|NIL|NA|???',
            '@P memberof',
            '@L memberof|---|CO|AP|PA|NIL|???',
            '@P phraseme',
            '@P del',
            '@L del|---|ELID|ELEX|EXPN|NIL|???',
            '@P quoted',
            '@L quoted|---|QUOT|NIL|???',
            '@P dsp',
            '@L dsp|---|DSP|DSPP|NIL|???',
            '@P coref',
            '@P cornum',
            '@P corsnt',
            '@L corsnt|---|PREV1|PREV2|PREV3|PREV4|PREV5|PREV6|PREV7|NIL|???',
            '@P dord',
            '@P parenthesis',
            '@L parenthesis|---|PA|NIL|???',
            '@P recip',
            '@L recip|---|YES|NO|NIL|???',
            '@P dispmod',
            '@L dispmod|---|DISP|NIL|NA|???',
            '@P trneg',
            '@L trneg|---|A|N|NA|???',

                        ]),

        'hint'      =>  ( join "\n",

                'tag:   ${tag}',
                'lemma: ${lemma}',
                'morph: ${x_morph}',
                'gloss: ${x_gloss}',
                'comment: ${x_comment}',

                        ),
        'patterns'  => [

                'svn: $' . 'Revision' . ': $ $' . 'Date' . ': $',

                'style:' . q {<?

                        (

                            DeepLevels::isClauseHead() ? '#{Line-fill:gold}' : ''

                        ) . (

                            $this->{context} eq 'B' ? '#{Node-shape:rectangle}#{Oval-fill:lightblue}' :
                            $this->{context} eq 'N' ? '#{Node-shape:rectangle}#{Oval-fill:magenta}' :
                            $this->{context} eq 'C' ? '#{Node-shape:rectangle}#{Oval-fill:blue}' : ''
                        )

                    ?>},

                q {<? $this->{form} ne '' ? $this->{lemma} =~ /^([^\_]+)/ ?
                                            $1 : '${form}' : '#{custom6}${origf}' ?>},

                q {<?

                        join '#{custom5}_', ( $this->{func} eq '???' && $this->{afun} ne '' ?
                        '#{custom3}${afun}' : '#{custom5}${func}' ), ( ( join '_', map {
                        '${' . $_ . '}' } grep { $this->{$_} ne '' }
                        qw 'parallel paren arabfa arabspec arabclause' ) || () )

                    ?>},

                q {<? '#{custom6}${x_comment} << ' if $this->{afun} ne 'AuxS' and $this->{x_comment} ne '' ?>}

                    . '#{custom2}${tag}',

                        ],
        'trees'     => [],
        'backend'   => 'Treex::PML::Backend::FS',
        'encoding'  => $encode,

    );
}


__END__


=head1 NAME

DeeperFS - Generating DeepLevels given a list of input Analytic documents


=head1 REVISION

    $Revision: 4948 $       $Date: 2012-10-17 00:12:17 +0200 (Wed, 17 Oct 2012) $


=head1 DESCRIPTION

Prague Arabic Dependency Treebank
L<http://ufal.mff.cuni.cz/padt/online/2007/01/prague-treebanking-for-everyone-video.html>


=head1 AUTHOR

Otakar Smrz, L<http://ufal.mff.cuni.cz/~smrz/>

    eval { 'E<lt>' . ( join '.', qw 'otakar smrz' ) . "\x40" . ( join '.', qw 'seznam cz' ) . 'E<gt>' }

Perl is also designed to make the easy jobs not that easy ;)


=head1 COPYRIGHT AND LICENSE

Copyright 2004-2008 by Otakar Smrz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

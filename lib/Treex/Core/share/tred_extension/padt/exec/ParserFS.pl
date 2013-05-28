#!/usr/bin/perl -w ###################################################################### 2004/04/15
#
# SyntaxFS.pl ########################################################################## Otakar Smrz

# $Id: ParserFS.pl 510 2008-03-14 15:33:07Z smrz $

use strict;

our $VERSION = do { q $Revision: 510 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };

BEGIN {

    our $libDir = `btred --lib`;

    chomp $libDir;

    eval "use lib '$libDir', '$libDir/libs/fslib', '$libDir/libs/pml-base'";
}

use Treex::PML 1.6;

use Encode;

use Encode::Arabic::Buckwalter ':xml';


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

    process_source($file);

    $file =~ s/(?:\.morpho)?\.fs$//;

    $target->writeFile($file . '.syntax.fs');
}


sub process_source {

    my $file = $_[0]; 

    my $para = 0;

    open F, '<', $file;

    local $/ = '';

    while (my $tree = <F>) {

	$tree =~ s/^\s+//;
	$tree =~ s/\s+$//;

	next if $tree eq "";

	my @tree = map { [ split /\t/, $_ ] } split /\n/, decode $decode, $tree;
	
        my $root = $target->new_tree($para++);

        $root->{'ord'} = 0;

        $root->{'afun'} = 'AuxS';

        $root->{'form'} = $para;

        $root->{'tag'} = 'TEXT';

        $root->{'comment'} = "$FStime [ParserFS.pl $VERSION]";

	$root->{'origf'} = $root->{'form'};

	my @node = ($root);

	for (my $i = 0; $i < @{$tree[0]}; $i++) {

	    my $node = Treex::PML::Factory->createNode();

	    $node->{'ord'} = $i + 1;
	    
	    $node->{'afun'} = $tree[2][$i];
	    
	    $node->{'form'} = $tree[0][$i];

	    $node->{'tag'} = $tree[1][$i];
	    
	    $node->{'comment'} = $tree[3][$i];

	    $node->{'origf'} = $node->{'form'};

	    $node->{'x_lookup'} = encode "buckwalter", $node->{'form'};
	    
	    push @node, $node;
	}

 	for (my $i = 1; $i < @node; $i++) {
    
 	    $node[$i]->paste_on($node[$node[$i]->{'comment'}], 'ord');
 	}
    }

    close F;
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
            '@H hide',

            map {

                '@P ' . $_,

                } qw 'reserve1 reserve2 reserve3 reserve4 reserve5',
                  qw 'x_id_ord x_input x_lookup x_morph x_gloss x_comment'

                        ),

        'hint'      =>  ( join "\n",

                'tag:   ${tag}',
                'lemma: ${lemma}',
                'morph: ${x_morph}',
                'gloss: ${x_gloss}',
                'comment: ${x_comment}',

                        ]),
        'patterns'  => [

                'svn: $' . 'Revision' . ': $ $' . 'Date' . ': $',

                'style:' . q {<?

                        Analytic::isClauseHead() ? '#{Line-fill:gold}' : ''

                    ?>},

                q {<? $this->{form} ne '' ? '${form}' : '#{custom6}${origf}' ?>},

                q {<?

                        join '#{custom1}_', ( $this->{afun} eq '???' && $this->{afunaux} ne '' ?
                        '#{custom3}${afunaux}' : '#{custom1}${afun}' ), ( ( join '_', map {
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

ParserFS - Generating Analytic given a list of input MST-parsed documents


=head1 REVISION

    $Revision: 510 $       $Date: 2008-03-14 16:33:07 +0100 (Fri, 14 Mar 2008) $


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

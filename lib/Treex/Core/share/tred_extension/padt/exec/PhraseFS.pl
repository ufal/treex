#!/usr/bin/perl -w ###################################################################### 2005/07/12
#
# PhraseFS.pl ########################################################################## Otakar Smrz

# $Id: PhraseFS.pl 4948 2012-10-16 22:12:17Z smrz $

use strict;

our $VERSION = do { q $Revision: 4948 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };

BEGIN {

    our $libDir = `btred --lib`;

    chomp $libDir;

    eval "use lib '$libDir', '$libDir/libs/fslib', '$libDir/libs/pml-base'";
}

use Treex::PML 1.6;

use MorphoMap 1.9;

use Encode::Arabic;


our $language = identify_language();

our $decode = "utf8";

our $encode = "utf8";


our $regexQ = qr/[0-9]+(?:[\.\,\x{060C}\x{066B}\x{066C}][0-9]+)? |
                 [\x{0660}-\x{0669}]+(?:[\.\,\x{060C}\x{066B}\x{066C}][\x{0660}-\x{0669}]+)?/x;

our $regexG = qr/[\.\,\;\:\!\?\`\"\'\(\)\[\]\{\}\<\>\\\|\/\~\@\#\$\%\^\&\*\_\=\+\-\x{00AB}\x{00BB}\x{060C}\x{061B}\x{061F}]/;


our ($target, $file, $FStime);

our ($twig, $this, $tree_lim, $node_lim, $term_lim);


# ##################################################################################################
#
# ##################################################################################################


@ARGV = glob join " ", @ARGV;


until (eof()) {

    $FStime = gmtime;

    $target = Treex::PML::Factory->createDocument({define_target_format()});

    $file = $ARGV;

    $/ = "(";

    $tree_lim = $node_lim = 0;

    $this = undef;

    until (eof) {

        $twig = decode $decode, scalar <>;

        $this = parse_twig($twig, $this);
    }

    foreach my $tree ($target->trees()) {

        justify_order($tree);
    }

    $file =~ s/\.tree$/_$language.tree/ unless $language eq '';

    $target->writeFile($file . '.fs') if $tree_lim > 0;

    printf "%s\t%s\n", $_, $file foreach keys %MorphoMap::AraMorph_POSVector_missing;

    %MorphoMap::AraMorph_POSVector_missing = ();
}


sub parse_twig {

    my ($twig, $this) = @_;

    my $node;

    my @tokens = map { split ' ', $_ } split /(\))/, $twig;

    warn "!!! No tokens to parse !!!" unless @tokens;

    while (@tokens) {

        if ($tokens[0] eq "(") {

            if (defined $this) {

                $node = Treex::PML::Factory->createNode();

                $node->{'ord'} = ++$node_lim;

                $node->paste_on($this, 'ord');

                $this = $node;
            }
            else {

                $this = $target->new_tree($tree_lim++);

                $node_lim = $term_lim = 0;

                $this->{'ord'} = ++$node_lim;

                $this->{'comment'} = "$FStime [PhraseFS.pl $VERSION]";
            }
        }
        elsif ($tokens[0] eq ")") {

            if (defined $this) {
        
                if ($this->parent()) {

                    $this = $this->parent();
                }
                else {

                    $this = undef;
                }
            }
            else {
            
                warn "!!! Non-matching right parenthesis !!!";
            }
        }
        elsif ($tokens[1] eq "(") {

            $this->{'label'} = $tokens[0];
            $this->{'morph'} = '';
        }
        elsif ($tokens[2] eq ")") {

            $this->{'label'} = $tokens[0];
            $this->{'morph'} = process_morph($tokens[1]);

            $this->{'tag_1'} = $tokens[0];

            unless ($language eq 'English') {

                if ($tokens[0] =~ /^FUT\+(IV.+)$/) {

                    $this->{'tag_2'} = MorphoMap::AraMorph_POSVector($1);

                    substr $this->{'tag_2'}, 4, 1, 'F';
                }
                elsif ($tokens[0] eq 'NO_FUNC') {

                    $this->{'tag_2'} = MorphoMap::AraMorph_POSVector('');
                }
                else {

                    $this->{'tag_2'} = MorphoMap::AraMorph_POSVector($tokens[0]);
                }

                $this->{'tag_3'} = MorphoMap::AraMorph_PennTBSet($tokens[0]);
            }

            $this->{'form'} = process_form($this->{'morph'});

            $this->{'origf'} = remove_diacritics($this->{'form'});

            $this->{'ord_term'} = ++$term_lim;

            shift @tokens;
        }
        else {

            warn "!!! Unrecognized tokens !!!" unless @tokens;
        }

        shift @tokens;
    }

    return $this;
}


sub process_morph {

    return $_[0] if $_[0] =~ /^(?:$regexQ|$regexG)+$/;

    my $morph = $_[0];

    $morph =~ s/-LRB-/\(/g;
    $morph =~ s/-RRB-/\)/g;

    return $morph if $language eq 'English';

    $morph =~ tr[{][A];

    $morph =~ s/uwo/uw/g;
    $morph =~ s/iyo/iy/g;

    $morph =~ s/\+awo(\-?)$/\+aw$1/;

    $morph =~ s/^(\-?)\~a(\-?)$/$1ya$2/;
    $morph =~ s/^(\-?)\~A(\-?)$/$1nA$2/;
    $morph =~ s/^(\-?)\~iy(\-?)$/$1iy$2/;

    return $morph;
}


sub process_form {

    return $_[0] if $_[0] =~ /^(?:$regexQ|$regexG)+$/;

    return $_[0] if $_[0] =~ /^\*(?:[A-Z0-9]+\*)?$/;

    return $_[0] if $language eq 'English';

    my $token = $_[0];

    $token =~ s/([tknhy])\+\1/$1\~/g;

    if ($this->{'tag_2'} =~ /^V/) {
    
        $token =~ s/\+aw(\-?)$/\+awoA$1/;
        $token =~ s/\+uw(\-?)$/\+uwA$1/;
    }
    else {
    
        $token =~ s/\+at((?:\+[aiuFKN])?\-?)$/\+ap$1/;
    }
    
    $token =~ s/([\|Awyo])[\>\&\<\}OWI]((?:\+[aiu])?\-?)$/$1\'$2/;

    $token =~ s/([\|A])\+a/$1/g;
 
    $token =~ s/([\|AY])\+[aui]$/$1/;
    $token =~ s/([\|AY])\+[FNK]$/$1\+F/;
    
    unless ($this->{'tag_2'} eq '----------') {

        $token =~ s/aY(?=\+F$)/Y/;
        $token =~ s/(?<!a)Y(?!\+F$)/aY/;
    }
        
    $token =~ s/(?<=a)Y(?=\+a)/y/;
    
    if ($token =~ /\+/ and $token ne '+') {

        $token =~ s/\+//g;
    }

    if ($token =~ /\-/ and $token ne '-') {

        $token =~ s/\-//g;
    }

    $token =~ s/\(null\)//g;

    $token = decode 'buckwalter', $token;

    return $token;
}


sub remove_diacritics {

    return $_[0] if $_[0] =~ /^(?:$regexQ|$regexG)+$/;

    return $_[0] if $_[0] =~ /^\*(?:[A-Z0-9]+\*)?$/;

    return $_[0] if $language eq 'English';

    my $text = encode 'buckwalter', shift;

    $text =~ tr[aiuoFKN\~\`\_][]d;

    return decode 'buckwalter', $text;
}


sub justify_order {

    my ($root) = @_;

    my ($index, $cnst) = (0, 0.001);

    my @nodes = ();

    my $this = $root->rightmost_descendant();

    if ($this == $root) {
    
        warn "!!! No node except the root !!!";
        
        $root->{'ord_just'} = 0;
        
        return;
    }
    
    do {

        $this->{'ord_just'} = $this->{'ord'} unless $this->firstson();

        $this->parent()->{'ord_just'} = $this->{'ord_just'} unless $this->rbrother();

        $this->parent()->{'ord_just'} = ($this->parent()->{'ord_just'} + $this->{'ord_just'} + $cnst) / 2 unless $this->lbrother();

        unshift @nodes, $this;
    }
    while $this = $this->previous($root) and $this != $root;

    unshift @nodes, $root;

    @nodes = sort { $a->{'ord_just'} <=> $b->{'ord_just'} } @nodes;

    foreach $this (@nodes) {

        $this->{'ord_just'} = ++$index;
    }
}


sub identify_language {

    my $return = '';

    if ($ARGV[0] eq '-L') {

        $return = $ARGV[1];

        splice @ARGV, 0, 2;
    }

    return $return;
}


sub define_target_format {

    return (

        'FS'        => Treex::PML::Factory->createFSFormat([

            '@P morph',
            '@P label',
            '@P tag_1',
            '@P tag_2',
            '@P tag_3',
            '@P comment',
            '@P form',
            '@P origf',
            '@P ref',
            '@N ord',
            '@P ord_just',
            '@P ord_term',
            '@H hide',

                        ]),

        'hint'      =>  ( join "\n",

                'morph: ${morph}',
                'label: ${label}',
                'tag_1: ${tag_1}',
                'tag_2: ${tag_2}',
                'tag_3: ${tag_3}',
                'comment: ${comment}',

                        ),
        'patterns'  => [

                'svn: $' . 'Revision' . ': $ $' . 'Date' . ': $',

                'mode:' . 'PhraseTrees',

                'rootstyle:' . q {<?

                        '#{vertical}#{Node-textalign:left}'

                    ?>},

                'style:' . q {<?

                        '#{Line-coords:n,n,p,n,p,p}'

                    ?>},

                q {<? $this->{morph} eq '' ? '#{custom1}${label}' : '#{custom6}${form}' ?>},

                '#{custom4}${tag_2}',
                '#{custom5}${tag_3}',
                '#{custom2}${morph}',
                '#{custom3}${tag_1}',

                        ],
        'trees'     => [],
        'backend'   => 'Treex::PML::Backend::FS',
        'encoding'  => $encode,

    );
}


__END__


=head1 NAME

PhraseFS - Generating PhraseTrees given a list of input Tree/Text documents


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

Copyright 2005-2008 by Otakar Smrz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

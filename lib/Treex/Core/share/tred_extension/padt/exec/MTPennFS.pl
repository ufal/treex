#!/usr/bin/perl -w ###################################################################### 2007/12/14
#
# MTPennFS.pl ########################################################################## Otakar Smrz

# $Id: MTPennFS.pl 480 2008-01-24 16:26:56Z smrz $

use strict;

our $VERSION = do { q $Revision: 480 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };

BEGIN {

    our $libDir = `btred --lib`;

    chomp $libDir;

    eval "use lib '$libDir', '$libDir/libs/fslib', '$libDir/libs/pml-base'";
}

use Treex::PML 1.6;

use MorphoMap 1.9;

use XMorph;

use Encode::Arabic;

use XML::Twig;

use Algorithm::Diff;


our $decode = identify_encoding();

our $encode = "utf8";

our %pronoun = identify_pronouns();


our $regexQ = qr/[0-9]+(?:[\.\,\x{060C}\x{066B}\x{066C}][0-9]+)? |
                 [\x{0660}-\x{0669}]+(?:[\.\,\x{060C}\x{066B}\x{066C}][\x{0660}-\x{0669}]+)?/x;

our $regexG = qr/[\.\,\;\:\!\?\`\"\'\(\)\[\]\{\}\<\>\\\|\/\~\@\#\$\%\^\&\*\_\=\+\-\x{00AB}\x{00BB}\x{060C}\x{061B}\x{061F}]/;


our ($source, $target, $file, $anno, $FStime, $DOCid);

our ($data, $this_par, $par_id, $word_tree, $prev_par, $anno_par);


# ##################################################################################################
#
# ##################################################################################################


@ARGV = glob join " ", @ARGV;


until (eof()) {

    $FStime = gmtime;

    $target = Treex::PML::Factory->createDocument({define_target_format()});

    $source = XML::Twig->new(

            'ignore_elts'   => {

                            'HEADER'    => 1,
                            'FOOTER'    => 1,

                               },

            'twig_roots'    => {

                            'DOC/DOCNO' => 1,

                            'HEADLINE'  => 1,
                            'hl'        => 1,

                            'DATELINE'  => 1,

                            'P'         => 1,
                            'p'         => 1,

                               },

            'twig_handlers' => {

                            'DOC/DOCNO' =>  \&parse_docno,

                            'HEADLINE'  =>  \&parse_headline,
                            'hl'        =>  \&parse_headline,

                            'DATELINE'  =>  \&parse_dateline,
                            
                            'P/seg'     =>  \&parse_seg,
                            'p/seg'     =>  \&parse_seg,

                            'P'         =>  \&parse_p,
                            'p'         =>  \&parse_p,

                               },

            'start_tag_handlers'    => {

                            'DOC'       => \&parse_doc,

                                       },

            );

    $file = $ARGV;

    $data = '';

    {
        local $/ = '</DOC>';

        $data .= <> until eof;

        $data =~ s/\n &HT;[^\n]*(?=\n &HT;|\n<\/HEADLINE>)//g;

        $data =~ s/&[A-Z][A-Za-z0-9]+;//g;

        $data =~ s/ & //g;
        
        $data =~ s/<seg id=([0-9]+)>/<seg id="$1">/g;        
    }

    $anno = process_anno($file);
    
    $source->parse($data);

    $source->purge();

    $target->tree($this_par - 1)->{'par'} = join '^', (split /[^0-9]+/, $target->tree($this_par - 1)->{'par'})[0], $this_par;

    $target->writeFile($file . '.morpho.fs');

    printf "%s\t%s\n", $_, $file foreach keys %MorphoMap::AraMorph_POSVector_missing;

    %MorphoMap::AraMorph_POSVector_missing = ();
}


sub process_anno {

    local $/ = '';

    my $file = $_[0];
    
    my ($chunk, @items, $item, $para, $word, $lookup, $choice, $number);
    my ($anno, $node);
    my ($para_last, $word_last);

    $anno = [];
    
    $para = ++$para_last;

    open F, '<', $file . ".anno";
    
    while ($chunk = <F>) {

        $chunk = decode "utf8", $chunk;

        $chunk =~ s/^\s+//;
        $chunk =~ s/\s+$//;

        @items = map { split /\:\s*/, $_, 2 } split /[\t\ ]*\n\s*/, $chunk;

        next unless @items;

        $word = ++$word_last;

        $node = {};

        $node->{'solution'} = [];

        $node->{'id'} = "P${para}W${word}";
        $node->{'comment'} = '';

        $number = 0;

        while (@items) {

            $item = shift @items;

            if ($item eq 'INPUT STRING') {

                $node->{'input'} = shift @items;
            }
            elsif ($item eq 'LOOK-UP WORD') {

                $node->{'lookup'} = $lookup = shift @items;

                # demode "buckwalter", 'noneplus';
                #
                # $node->{'input'} = decode "buckwalter", $node->{'lookup'};
                #
                # demode "buckwalter", 'default';
                #
                # $node->{'lookup'} = encode "buckwalter", $node->{'input'};
                #
                # if ($node->{'lookup'} ne $lookup) {
                #
                #     warn "Lookup '" . $node->{'lookup'} . "' << '$lookup' in $para/$word";
                # }
            }
            elsif ($item eq 'Comment') {

                $item = shift @items;
            
                $node->{'comment'} = normalize_comment($item);
            }
            elsif ($item eq 'INDEX') {

                $item = shift @items;

                ($para, $word) = $item =~ /^P(\d+)W(\d+)$/;

                if (defined $para and defined $word) {

                    $para_last = $para;
                    $word_last = $word;
                }

                $node->{'id'} = $item;
            }
            elsif (($choice, $number) = $item =~ /^((?:[\*X]\s+)?)SOLUTION\s+(\d+)$/) {

                $item = shift @items;

                unless ($choice eq '') {

                    $node->{'solutionno'} = $number;

                    ($node->{'translit'}, $node->{'tag'}) = $item =~ m{^\(([^)]*)\)\s+(.*)$};

                    if (exists $node->{'translit'}) {

                        unless ($node->{'translit'}) {

                            # warn "Null translit for '". $node->{'input'} . "' in $para/$word";

                            $node->{'translit'} = $node->{'lookup'};
                        }
                    }
                }

                push @{$node->{'solution'}}, $item;
                
                $item = shift @items;

                if (defined $item and $item eq '(GLOSS)') {

                    push @{$node->{'gloss'}}, shift @items;
                }
                else {

                    unshift @items, $item if defined $item;

                    push @{$node->{'gloss'}}, '';

                    $node->{'lookup'} = $node->{'input'} unless defined $node->{'lookup'} and warn "Lookup defined!\n";

                    # warn "No gloss with '$node->{'solution'}' in $para/$word";
                }
            }
            else {

                die "Parsing problem with '$item' in $para/$word";
            }
        }

        $anno->[$para - 1]->[$word - 1] = $node;

        if ($number > 0) {

            # warn "No annotation with '" . $node->{'lookup'} . "' in $para/$word" unless exists $node->{'solutionno'};
        }
        else {

            warn "No solution with '" . ( encode "buckwalter", $node->{'input'} ) . "' in $para/$word";

            $node->{'translit'} = exists $node->{'lookup'} ? $node->{'lookup'}
                                                           : encode "buckwalter", $node->{'input'};
        }
    }

    close F;
        
    return $anno;
}


sub parse_doc {

    my ($twig, $elem) = @_;

    my $date = $elem->att('docid') || $elem->att('id') || '';

    my $type = $elem->att('type');

    my $language = $elem->att('language');

    $DOCid = join '_', $date, grep { defined $_ and $_ ne '' } $type, $language;

    ($par_id, $word_tree, $prev_par) = (0, 0, 1);
}


sub parse_docno {

    my ($twig, $elem) = @_;

    $DOCid = $elem->text();
}


sub parse_headline {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('HEADLINE', $text, $elem->name() eq 'HEADLINE' ? undef : shift @{$anno});
}


sub parse_dateline {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('DATELINE', $text, shift @{$anno});
}


sub parse_seg {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('TEXT', $text, shift @{$anno});
}


sub parse_p {

    my ($twig, $elem) = @_;

    warn "Problems with $file ...\n" if grep { $_->name() eq 'seg' } $elem->children();

    my $text = $elem->text();

    $twig->purge();

    process_text('TEXT', $text, shift @{$anno}) unless $text =~ /^\s*$/;
}


sub process_text {

    my ($meta, $data, $anno) = @_;

    my ($node, $input, $lookup, $remove, $ord, $tag);

    my ($word_in_par, $l, $i);

    my (@nodes, @lookups, @queue, @morpho, @lem_id) = ();

    my (%repeated, %cluster);

    $anno = [] unless defined $anno;
    
    $word_in_par = 0;
    

    $data = decode $decode, $data if defined $decode;

    while ($data =~ /(?: \G \P{IsGraph}* ( (?: \p{Arabic} | [\x{064B}-\x{0652}\x{0670}\x{0657}\x{0656}\x{0640}] |
                                             # \p{InArabic} |   # too general
                                            \p{InArabicPresentationFormsA} | \p{InArabicPresentationFormsB} )+ |
                                            \p{Latin}+ |
                                            $regexQ |
                                            $regexG |
                                            \p{IsGraph} ) )/gx) {

        $node = {};

        $node->{'input'} = $input = $1;
                
        if ($input =~ /^$regexQ$/) {

            $node->{'lookup'} = $lookup = encode 'buckwalter', $input;

            $node->{'morpho'} = [ [ "() [DEFAULT] " . $lookup . "/NUM", "", 'annotate' ] ];
        }
        elsif ($input =~ /^$regexG$/) {

            $node->{'lookup'} = $lookup = $input;

            $node->{'morpho'} = [ [ "() [DEFAULT] " . $lookup . "/PUNC", "", 'annotate' ] ];
        }
        else {

            # any real analysis postoned until after LCS
        }

        push @nodes, $node;
    }

    $this_par = ++$par_id + $word_tree;

    my $root = $target->new_tree($this_par - 1);

    $root->{'type'} = 'paragraph';
    $root->{'id'} = "#$par_id";

    $root->{'input'} = $meta;

    $root->{'ord'} = $ord = 0;

    $root->{'comment'} = "$DOCid $FStime [MTPennFS.pl $VERSION]";

    Algorithm::Diff::traverse_sequences(\@nodes, $anno, { 'MATCH' => sub { $nodes[$_[0]]->{'anno'} = $anno->[$_[1]] } }, 
                                                        sub { return $_[0]->{'input'} });

    foreach $node (@nodes) {

        next if exists $node->{'morpho'};
    
        $node->{'morpho'} = [];
    
        if (exists $node->{'anno'}) {
        
            $anno = $node->{'anno'};
        
            $node->{'apply_t'} = 1;
            
            $node->{$_} = $anno->{$_} foreach qw 'id lookup comment';            

            $node->{'morpho'} = [];
            
            if (@morpho = @{$anno->{'solution'}}) {

                $node->{'morpho'} = [ map { [ $anno->{'solution'}[$_], $anno->{'gloss'}[$_] ] } 0 .. @morpho - 1 ];
                
                push @{$node->{'morpho'}->[$anno->{'solutionno'} - 1]}, 'annotate' if exists $anno->{'solutionno'};
                
                $node->{'morpho'} = [ grep { $_->[1] !~ /NOT_IN_LEXICON/ } @{$node->{'morpho'}} ];
            }
        }
            
        $node->{'morpho'} = [ [ '(' . $node->{'lookup'} . ') ' .
                                      $node->{'lookup'} . '/NIL', 'NOT_IN_LEXICON' ] ] unless @{$node->{'morpho'}};
    }
                                                        
    foreach $node (@nodes) {

        my $wordnode = Treex::PML::Factory->createNode();

        $wordnode->{'type'} = 'word_node';
        $wordnode->{'ref'} = ++$word_tree + $par_id;
        $wordnode->{'ord'} = ++$ord;

        $wordnode->{$_} = $node->{$_} foreach qw 'input id apply_t';

        $wordnode->paste_on($root, 'ord');
    }

    $root->{'par'} = $prev_par . '^';
    $prev_par = $this_par;
    $root->{'par'} .= $word_tree + $par_id + 1;

    $word_in_par = 0;

    foreach $node (@nodes) {

        my $root = $target->new_tree(++$word_in_par + $this_par - 1);

        $root->{'type'} = 'entity';
        $root->{'id'} = "#$par_id/" . $word_in_par;
        $root->{'ref'} = $this_par;
        $root->{'ord'} = $ord = 0;

        $root->{$_} = $node->{$_} foreach qw 'input lookup comment';

        process_node_morpho($node);

        foreach (@{$node->{'token_info'}}) {

            push @{$node->{'partition'}{remove_diacritics(join " ", map { $_->[0] } @{$_}[1 .. @{$_} - 1])}}, $_;
        }

        foreach (sort keys %{$node->{'partition'}}) {

            my $partinode = Treex::PML::Factory->createNode();

            $partinode->{'type'} = 'partition';
            $partinode->{'form'} = $_;
            $partinode->{'ord'} = ++$ord;

            $partinode->paste_on($root, 'ord');

            for ($l = 1; $l < @{$node->{'partition'}{$_}->[0]}; $l++) {

                my $morphonode = Treex::PML::Factory->createNode();

                $morphonode->{'type'} = 'token_form';
                $morphonode->{'form'} = remove_diacritics($node->{'partition'}{$_}->[0][$l][0]);
                $morphonode->{'ord'} = ++$ord;
                
                $morphonode->paste_on($partinode, 'ord');

                %repeated = ();
                %cluster = ();

                for ($i = 0; $i < @{$node->{'partition'}{$_}}; $i++) {

                    push @{$cluster{$node->{'partition'}{$_}->[$i][$l][4]}}, $node->{'partition'}{$_}->[$i][$l];
                }

                foreach (sort keys %cluster) {

                    my $lemmanode = Treex::PML::Factory->createNode();

                    @lem_id = restore_lemma($_);

                    $lemmanode->{'type'} = 'lemma_id';
                    $lemmanode->{'form'} = $lem_id[0];
                    $lemmanode->{'id'} = $lem_id[1];
                    $lemmanode->{'ord'} = ++$ord;

                    $lemmanode->{'gloss'} = join '/', sort keys %{XMorph::analyze(@lem_id)};

                    $lemmanode->paste_on($morphonode, 'ord');

                    for ($i = 0; $i < @{$cluster{$_}}; $i++) {

                        foreach $tag (MorphoMap::distinguish_POSVector($cluster{$_}[$i]->[2])) {

                            my $info = join " ", $cluster{$_}[$i]->[0], $cluster{$_}[$i]->[4], $tag;
                        
                            if (exists $repeated{$info}) {
                            
                                $repeated{$info}->{'apply_t'} = 1 if $cluster{$_}[$i]->[5] eq 'annotate';
                            
                                next;
                            }

                            my $tokennode = Treex::PML::Factory->createNode();

                            $repeated{$info} = $tokennode;

                            $tokennode->{'apply_t'} = 1 if $cluster{$_}[$i]->[5] eq 'annotate';
                            
                            $tokennode->{'type'} = 'token_node';
                            $tokennode->{'form'} = $cluster{$_}[$i]->[0];
                            $tokennode->{'morph'} = $cluster{$_}[$i]->[1];
                            $tokennode->{'tag'} = $tag;

                            $tokennode->{'gloss'} = $cluster{$_}[$i]->[3];
                            $tokennode->{'gloss'} =~ s/[\+\ ]+$//;

                            $tokennode->{'ord'} = ++$ord;

                            $tokennode->paste_on($lemmanode, 'ord');
                        }
                    }
                }
            }
        }
    }
}


# ##################################################################################################
#
# ##################################################################################################

# process the string of morphological analysis

sub process_node_morpho {

    my ($node) = @_;
    my (@token_info, @morpheme_buffer, @morphemes, @glosses, $lemma_id, $i, $m, $remember, $info);

    # $node->{'morpho'} = [];   # to include elements of the form ['translit', 'lemma_id', 'tag', 'gloss', 'number', 'annotate' / '']

    if (exists $node->{'morpho'} and @{$node->{'morpho'}}) {

        # extract the elements out of the analyzer's string

        $node->{'morpho'} = [ map { [

                                        $_->[0] =~ m/^\( ( [^\)]* ) \) \s* ((?: \[ [^\]]* \] )?) \s* (.*)$/x,
                                        $_->[1],
                                        ++$i,
                                        defined $_->[2] ? $_->[2] : ''

                                ] } @{$node->{'morpho'}} ];

        $node->{'token_info'} = [];

        foreach $info (@{$node->{'morpho'}}) {

            @token_info = ($info->[1]);    # remember the lemma_id

            @morpheme_buffer = ();

            if (defined $info->[2]) {

                $info->[2] =~ s/\s+//g;

                $info->[2] =~ s/\-//g unless $info->[2] eq '-/PUNC';
            }
            else {

                warn "Morpho undefined, token_info = '@token_info', remember = '$remember'\n";

                $info->[2] = "";
            }

            $remember = $info->[1];

            @morphemes = split /\+(?!\/PUNC)/, $info->[2];

            @glosses = split /\s*\+\s*/, $info->[3];   # '+/PUNC' is fine .. no glosses for non-words
            push @glosses, ('') x (@morphemes - @glosses);

            for ($m = 0; $m < @morphemes; $m++) {

                if (MorphoMap::morph_is_prefix($morphemes[$m]) and $m < @morphemes - 1) {

                    # fill the buffer and complete the info on the token being this morpheme

                    $lemma_id = $morphemes[$m];

                    push @morpheme_buffer, [$morphemes[$m], $glosses[$m]];
                    push @token_info, process_morpheme_buffer(\@morpheme_buffer, $lemma_id);
                }
                elsif (MorphoMap::morph_is_suffix($morphemes[$m]) and $m > 0) {

                    # complete the info on the token defined by the previous sequence of morphemes
                    # buffer the current morpheme

                    push @token_info, process_morpheme_buffer(\@morpheme_buffer, $lemma_id);
                    push @morpheme_buffer, [$morphemes[$m], $glosses[$m]];

                    $lemma_id = $morphemes[$m];
                }
                else {

                    # buffer the current morpheme

                    push @morpheme_buffer, [$morphemes[$m], $glosses[$m]];

                    $lemma_id = $token_info[0];
                }
            }

            push @token_info, process_morpheme_buffer(\@morpheme_buffer, $lemma_id);

            push @{$node->{'token_info'}}, [ $token_info[0], 
                                             map { [ @{$_}, $info->[5] ] } @token_info[1 .. @token_info - 1] ];
        }
    }
    else {

        warn "Empty token_info, which is highly improbable and risky!\n";

        $node->{'token_info'} = [ [] ];
    }
}


# process the token's morphological information

sub process_morpheme_buffer {

    my ($ref, $lemma) = @_;

    return unless @$ref;

    my $tim = join "+", map { $_->[0] =~ m{^.*/(.*)}; $1 } @$ref;

    my $tag = MorphoMap::AraMorph_POSVector($tim);

    my $morph = join "+", map { $_->[0] =~ m{^(.*)/}; $1 } @$ref;

    $morph =~ tr[{][A];

    $morph =~ s/uwo/uw/g;
    $morph =~ s/iyo/iy/g;

    $morph =~ s/\+awo$/\+aw/;

    $morph =~ s/^\~a$/ya/;
    $morph =~ s/^\~A$/nA/;
    $morph =~ s/^\~iy$/iy/;

    my $token = $morph;

    my $gloss = join " + ", map { $_->[1] } @$ref;

    @$ref = ();

    $lemma =~ tr[{][A];

    $lemma =~ s/uwo/uw/g;
    $lemma =~ s/iyo/iy/g;

    $lemma =~ s/([\|A])a/$1/g;

    $lemma =~ s/\/RC_PART$/\/EMPH_PART/;

    $lemma = identify_pronoun($lemma, $tag);

    $token =~ s/([tknhy])\+\1/$1\~/g;

    if ($tag =~ /^V/) {
    
        $token =~ s/\+aw$/\+awoA/;
        $token =~ s/\+uw$/\+uwA/;
    }
    else {
    
        $token =~ s/\+at((?:\+[aiuFKN])?)$/\+ap$1/;
    }

    $token =~ s/([\|Awyo])[\>\&\<\}OWI]((?:\+[aiu])?)$/$1\'$2/;

    $token =~ s/([\|A])\+a/$1/g;

    $token =~ s/([\|AY])\+[aui]$/$1/;
    $token =~ s/([\|AY])\+[FNK]$/$1\+F/;

    unless ($tag eq '----------') {
    
        $token =~ s/aY(?=\+F$)/Y/;
        $token =~ s/(?<!a)Y(?!\+F$)/aY/;
    }

    $token =~ s/(?<=a)Y(?=\+a)/y/;
    
    if ($token =~ /\+/ and $token ne '+') {

        $token =~ s/\+//g;
    }

    if ($token =~ /\-/ and $token ne '-') {

        warn "Reducing '-' in '$token'";
        $token =~ s/\-//g;
    }

    $token =~ s/\(null\)//g;

    $token = decode 'buckwalter', $token unless $token =~ /^(?:$regexQ|$regexG)$/;

    return [$token, $morph, $tag, $gloss, $lemma];
}


sub normalize_comment {

    my ($text) = @_;
    
    $text =~ tr[{][A];

    $text =~ tr[,;:][]d;
    $text =~ tr[\t][ ];
  
    $text =~ s/NO[_ ]MATCH//ig; 
    $text =~ s/should be /SHOULD_BE /ig; 
    
    $text =~ s/ +/ /g;
    $text =~ s/^ //;
    $text =~ s/ $//;
    
    return $text;
}


sub restore_lemma {

    my ($lemma, $idx) = $_[0] =~ /^\[ ([^\_]*) \_ ([^\]*]) \]$/x;

    ($lemma, $idx) = $_[0] =~ /^([^\/]*) \/ (.*)$/x unless $lemma;

    printf "%s\t%s\n", $lemma, $file if defined $idx and $idx !~ /^(?:PRONOUN|[1-5])$/ and
                                        MorphoMap::AraMorph_POSVector($idx) eq '-' x 10;

    return ( ( decode 'buckwalter', $lemma ), $idx ) if $lemma;

    return $_[0], '?';
}


sub remove_diacritics {

    return $_[0] if $_[0] =~ /^(?:$regexQ|$regexG)$/;

    my $text = encode 'buckwalter', shift;

    $text = remove_diacritics_buckwalter($text);

    return decode 'buckwalter', $text;
}


sub remove_diacritics_buckwalter {

    my $text = shift;

    $text =~ tr[aiuoFKN\~\`\_][]d;

    return $text;
}


sub identify_pronoun {

    my ($lemma, $idx) = $_[0] =~ /^([^\/]*) \/ (.*)$/x;
    my ($tag) = $_[1];

    if ($tag =~ /^S-/ and defined $lemma) {

        if (exists $pronoun{substr $tag, 0, 8}) {

            return $pronoun{substr $tag, 0, 8} . '/PRONOUN';
        }
        else {

            printf "%s\t%s\n", $_[0], $file;
        }
    }

    return $_[0];
}


sub identify_pronouns {

    return (

        'S----1-S'          =>      '>anA',
        'S----2MS'          =>      '>anota',
        'S----2FS'          =>      '>anoti',
        'S----3MS'          =>      'huwa',
        'S----3FS'          =>      'hiya',

        'S----1-P'          =>      'naHonu',
        'S----2MP'          =>      '>anotum',
        'S----2FP'          =>      '>anotun~a',
        'S----3MP'          =>      'hum',
        'S----3FP'          =>      'hun~a',

        'S----2-D'          =>      '>anotumA',
        'S----3-D'          =>      'humA',

    );
}


sub identify_encoding {

    my $return = undef;

    if ($ARGV[0] eq '-E') {

        $return = $ARGV[1];

        splice @ARGV, 0, 2;
    }

    return $return;
}


sub define_target_format {

    return (

        'FS'        => Treex::PML::Factory->createFSFormat([

            '@N ord',
            '@P type',
            '@L type|paragraph|word_node|entity|partition|token_form|lemma_id|token_node',
            '@P tips',
            '@P inherit',
            '@H hide',
            '@P restrict',
            '@P ref',
            '@P par',
            '@V input',
            '@P input',

            map {

                '@P ' . $_,

                } qw 'solution form morph tag gloss lookup id apply_m apply_t comment'

                        ]),

        'hint'      => q {<? '${gloss}' if $this->{type} eq 'token_node' ?>},
        'patterns'  => [

                'svn: $' . 'Revision' . ': $ $' . 'Date' . ': $',

                'style:' . q {<?

                        $this->{apply_m} > 0 ? '#{Line-fill:red}' : 
                                               $this->{apply_t} > 0 ? '#{Line-fill:orange}' :
                                                                      defined $this->{apply_m} ? '#{Line-fill:black}' : ''

                    ?>},

                q {<?   '#{magenta}${comment} << ' if $this->{type} !~ /^(?:token_node|paragraph)$/ and $this->{comment} ne ''  ?>} .

                q {<?
                        $this->{type} =~ /^(?:token_node|token_form|partition)$/

                            ? ( '${form}' )

                            : (

                            $this->{type} eq 'lemma_id'

                                ? ( '#{purple}${gloss} #{gray}${id} #{darkmagenta}${form}' )
                                : (

                                $this->{type} =~ /^(?:entity|paragraph)$/

                                    ? ( $this->{apply_m} > 0

                                        ? '#{black}${id} #{gray}${lookup} #{red}${input}'
                                        : '#{black}${id} #{gray}${lookup} #{black}${input}'
                                    )
                                    : ( $this->{apply_m} > 0

                                        ? '  #{red}${input}'
                                        : '  #{black}${input}'
                                    )
                                )
                            )
                    ?>},

                q {<? '#{goldenrod}${comment} << ' if $this->{type} eq 'token_node' and $this->{comment} ne '' ?>} .

                '#{darkred}${tag}' . q {<?

                        $this->{inherit} eq '' ? '#{red}' : '#{orange}'

                    ?>} . '${restrict}',

                        ],
        'trees'     => [],
        'backend'   => 'Treex::PML::Backend::FS',
        'encoding'  => $encode,

    );
}


__END__


=head1 NAME

MTPennFS - Generating MorphoTrees given input XML/SGML documents and POS annotations of the Penn ATB


=head1 REVISION

    $Revision: 480 $       $Date: 2008-01-24 17:26:56 +0100 (Thu, 24 Jan 2008) $


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

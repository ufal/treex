package Treex::Block::Align::A::AlignMGiza;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use FileUtils;
use File::Temp;

use Treex::Core::Resource qw(require_file_from_share);

has from_language => ( isa => 'Str', is => 'ro', required => 1 );
has from_selector => (isa => 'Str', is => 'rw', default => '' );
has to_selector => (isa => 'Str', is => 'rw', default => '' );
has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has align_attr => ( isa => 'Str', is => 'ro', default => 'lemma' );
has dir_or_sym => ( isa => 'Str', is => 'rw', default => 'grow-diag-final-and' );
has tmp_dir => ( isa => 'Str', is => 'ro', default => '/mnt/h/tmp' );
has cpu_cores => ( isa => 'Int', is => 'rw', default => '-1' ); # -1 means autodetect
has model => ( isa => 'Str', is => 'rw', default => "$ENV{TMT_ROOT}/share/data/models/mgiza/en-cs" );
has model_from_share => ( isa => 'Str', is => 'ro' );
has mgizadir => ( is => 'rw', isa => 'Str', default => "$ENV{TMT_ROOT}/share/installed_tools/mgizapp/install" );

my $mytmpdir;
my @parsed_dir_or_sym;

use Config;
#log_fatal $self->mgizadir . "contains binaries compiled for 'x86_64-linux' but you are using '$Config{archname}'." if $Config{archname} ne 'x86_64-linux';

sub process_document {
    my ( $self, $document ) = @_; 

    @parsed_dir_or_sym = split ',', $self->dir_or_sym;

    # create tempdir
    $mytmpdir = File::Temp::tempdir( "alignmgizaXXXXXX", DIR => $self->tmp_dir );
    log_info "Created temporary dir: $mytmpdir";

    # set number of cores
    if ( $self->cpu_cores == -1 ) {
        chomp(my $cores = `cat /proc/cpuinfo | grep -E '^(CPU|processor)' | wc -l`);
        $self->set_cpu_cores( $cores );
    }
    log_info "Using " . $self->cpu_cores . " cores";

    log_info "Writing document as plain text";

    # output sentences into plain text
    _write_plain( $document, $self->from_language, $self->from_selector, $self->align_attr, "$mytmpdir/txt-a" );
    _write_plain( $document, $self->to_language,   $self->to_selector, $self->align_attr, "$mytmpdir/txt-b" );

    # acquire model from share if required
    if ( defined $self->model_from_share ) {
        
        # list of necessary files
        my @mgiza_model_files = (
            'a-b.D4.final',
            'a-b.a3.final',
            'a-b.d3.final',
            'a-b.d4.final',
            'a-b.gizacfg',
            'a-b.n3.final',
            'a-b.t3.final',
            'b-a.D4.final',
            'b-a.a3.final',
            'b-a.d3.final',
            'b-a.d4.final',
            'b-a.gizacfg',
            'b-a.n3.final',
            'b-a.t3.final',
            'vcb-a',
            'vcb-a.classes',
            'vcb-b',
            'vcb-b.classes',
        );
        
        # get path to files
        my $basepath = 'data/models/mgiza/' . $self->model_from_share . '/';
        # require the first file - returns path to the file
        my $path = require_file_from_share( $basepath . $mgiza_model_files[0] , ref($self) );
        # remove the last slash and the file name
        $path =~ s/\/[^\/]+$//;
        # set the model path
        $self->set_model( $path );
        
        # acquire files
        foreach my $file (@mgiza_model_files) {
            require_file_from_share( $basepath . $file , ref($self) );
        }
        
    }

    # symlink word classes
    symlink( $self->model . "/vcb-a.classes", "$mytmpdir/vcb-a.classes" );
    symlink( $self->model . "/vcb-b.classes", "$mytmpdir/vcb-b.classes" );

    log_info "Creating vocabulary files";

    # create vocabulary lists
    my $src_vcb = _update_vocabulary( "$mytmpdir/txt-a", $self->model . "/vcb-a", "$mytmpdir/vcb-a" );
    my $tgt_vcb = _update_vocabulary( "$mytmpdir/txt-b", $self->model . "/vcb-b", "$mytmpdir/vcb-b" );

    log_info "Running MGiza";

    # run mgiza
    my ( $ranthere, $ranback ) = qw( 0 0 );
    if ( grep { $_ eq 'left' } @parsed_dir_or_sym ) {
        $self->_run_mgiza( $src_vcb, $tgt_vcb, 0 );
        $self->_store_uni_align( $document, 'left' );
        $ranthere = 1;
    }
    if ( grep { $_ eq 'right' } @parsed_dir_or_sym ) {
        $self->_run_mgiza( $tgt_vcb, $src_vcb, 1 );
        $self->_store_uni_align( $document, 'right' );
        $ranback = 1;
    } 
    if ( grep { $_ ne 'right' && $_ ne 'left' } @parsed_dir_or_sym ) {
        # run mgiza in both directions if necessary and merge
        $self->_run_mgiza( $src_vcb, $tgt_vcb, 0 ) if ! $ranthere;
        $self->_run_mgiza( $tgt_vcb, $src_vcb, 1 ) if ! $ranback;
        $self->_store_bi_align( $document );
    }
}

sub _write_plain {
    my ( $document, $language, $selector, $attr, $file ) = @_;
    my $hdl = _my_save( $file );
    for my $bundle( $document->get_bundles ) {
        my @nodes = $bundle->get_zone( $language , $selector)->get_atree->get_descendants( { ordered => 1 } );
        print $hdl join( " ", map { s/ /_/g; $_ } map { $_->get_attr( $attr ) } @nodes ), "\n";    
    }
    close $hdl;
}

# given existing vocabulary file, add unknown words from txt_file
# and store the new vocabulary in newvcb_file
# return the new vocabulary 
sub _update_vocabulary {
    my ( $txt_file, $oldvcb_file, $newvcb_file ) = @_;
    my $oldvcb_hdl = _my_open( $oldvcb_file );
    my $newvcb_hdl = _my_save( $newvcb_file );
    my %vcb;
    my @unk;
    my $lastid = 0;

    # read existing vcb
    while ( <$oldvcb_hdl> ) {
        chomp;
        my ( $id, $word, $count ) = split;
        $vcb{$word} = $id;
        $lastid = $id;
        print $newvcb_hdl join("\t", $id, $word, $count), "\n";
    }
    close $oldvcb_hdl;

    # get unknown words and update the new vcb
    my $txt_hdl = _my_open( $txt_file );
    while ( <$txt_hdl> ) {
        chomp;
        my @words = split;
        for my $word ( @words ) {
            if ( ! defined $vcb{$word} ) {
                $vcb{$word} = ++$lastid;
                push @unk, $word;
                print $newvcb_hdl "$lastid\t$word\t1\n";
            }
        }
    }
    close $txt_hdl;
    close $newvcb_hdl;

    return \%vcb;
}

sub _create_corpus {
    my ( $outfile, $src_txt, $src_vcb, $tgt_txt, $tgt_vcb ) = @_;
    my $out_hdl = _my_save( $outfile );
    my $src_hdl = _my_open( $src_txt );
    my $tgt_hdl = _my_open( $tgt_txt );

    while ( my $src_line = <$src_hdl> ) {
        chomp( $src_line );
        chomp( my $tgt_line = <$tgt_hdl> );
        my @src_numbers = map { $src_vcb->{$_} } split / /, $src_line;
        my @tgt_numbers = map { $tgt_vcb->{$_} } split / /, $tgt_line;
        print $out_hdl "1\n", join( " ", @tgt_numbers ), "\n", join( " ", @src_numbers ), "\n";
    }
    close $out_hdl;
}

sub _parse_dirsym {
    my $dirsym = shift;
    my $alitype = undef;
    my $revneeded = 0;
    my $alidiag = "no";
    my $alifinal = "no";
    my $alifinaland = "no";

    if ($dirsym =~ /^rev/) {
        $revneeded = 1;
        $dirsym =~ s/^rev//;
    }

    if ($dirsym eq "left" || $dirsym eq "right") {
        # ok
    } elsif ($dirsym eq "int" || $dirsym eq "intersect" || $dirsym eq "intersection") {
        $alitype = "intersect";
    } elsif ($dirsym eq "uni" || $dirsym eq "union") {
        $alitype = "union";
    } elsif ($dirsym eq "g" || $dirsym eq "grow") {
        $alitype = "grow";
    } elsif ($dirsym eq "gd" || $dirsym eq "grow-diag") {
        $alitype = "grow";
        $alidiag = "yes";
    } elsif ($dirsym eq "gdf" || $dirsym eq "grow-diag-final") {
        $alitype = "grow";
        $alidiag = "yes";
        $alifinal = "yes";
    } elsif ($dirsym eq "gdfa" || $dirsym eq "grow-diag-final-and") {
        $alitype = "grow";
        $alidiag = "yes";
        $alifinal = "yes";
        $alifinaland = "yes";
    }
    return ( $revneeded, "-alignment='$alitype' -diagonal='$alidiag'"
                        . " -final='$alifinal' -both='$alifinaland'" );
}

sub _run_mgiza {
    my ( $self, $src_vcb, $tgt_vcb, $inverse ) = @_;
    my $a = $inverse ? "b" : "a";
    my $b = $inverse ? "a" : "b";

    # prepare training corpus
    my $corpus = "$mytmpdir/$a-$b.snt";
    _create_corpus( $corpus, "$mytmpdir/txt-$a", $src_vcb, "$mytmpdir/txt-$b", $tgt_vcb );

    # prepare coocurrence file
    my $cooc_file = "$mytmpdir/$a-$b.cooc";
    my $snt2cooc = $self->mgizadir . '/bin/snt2cooc';
    _safesystem( "$snt2cooc $cooc_file $mytmpdir/vcb-$a $mytmpdir/vcb-$b $corpus" );

    # generate options for MGiza
    my %mgiza_options = ( 
        previoust => $self->model . "/$a-$b.t3.final" ,
        previousa => $self->model . "/$a-$b.a3.final" ,
        previousd => $self->model . "/$a-$b.d3.final" ,
        previousn => $self->model . "/$a-$b.n3.final" ,
        previousd4 => $self->model . "/$a-$b.d4.final" ,
        previousd42 => $self->model . "/$a-$b.D4.final" ,
        m1 => 0 , 
        m2 => 0 , 
        mh => 0 , 
        m3 => 0 , 
        m4 => 1 , 
        restart => 11 ,
        s => "$mytmpdir/vcb-$b",
        t => "$mytmpdir/vcb-$a",
        c => $corpus,
        ncpu => $self->cpu_cores,
        coocurrence => $cooc_file,
        o => "$mytmpdir/$a-$b"
    );

    my $options_str;
    map { $options_str .= " -$_ $mgiza_options{$_}" } sort keys %mgiza_options;

    # run mgiza
    my $mgiza = $self->mgizadir . '/bin/mgiza';
    _safesystem( "$mgiza " . $self->model . "/a-b.gizacfg $options_str" );

    # merge alignment parts
    my $merge = $self->mgizadir . '/scripts/merge_alignment.py';
    _safesystem( "$merge $mytmpdir/$a-$b.A3.final.part* > $mytmpdir/$a-$b.A3.final" );

    # remove alignment parts
    _safesystem( "rm -f $mytmpdir/$a-$b.A3.final.part*" );
}

sub _store_uni_align {
    my ( $self, $document, $direction ) = @_;
    my ( $a, $b );
    my $inv = ( $direction eq "left" ) ? 0 : 1;
    if ( ! $inv ) {
        $a = 'a';
        $b = 'b';
    } else { # inverse alignment
        $a = 'b';
        $b = 'a';
    }
    my $ali_hdl = _my_open( "$mytmpdir/$a-$b.A3.final" );
    my @bundles = $document->get_bundles;

    # read the MGiza output
    my $sent_number = 0;
    while ( ! eof $ali_hdl ) {
        $sent_number++;
        my $bundle = shift @bundles;
        my $src_root = $bundle->get_zone( $self->from_language, $self->from_selector )->get_atree;
        my $tgt_root = $bundle->get_zone( $self->to_language, $self->to_selector )->get_atree;
        my @src_nodes = $src_root->get_descendants( { ordered => 1 } );
        my @tgt_nodes = $tgt_root->get_descendants( { ordered => 1 } );

        # get alignment for one sentence
        my ( $alignment, $aliscore ) = _read_align( $ali_hdl );

        # set tree alignment score and counterpart
        $src_root->set_attr( "giza_scores/counterpart.rf", $tgt_root->id );
        my $score_direction = $inv ? "back" : "there"; # XXX is this correct
        $src_root->set_attr( "giza_scores/" . $score_direction .  "value", $aliscore );

        # store all alignment points
        for ( my $i = 0; $i < scalar @$alignment; $i++ ) {
            next if ! defined $alignment->[$i] || $alignment->[$i] == 0;
            my $from = $inv ? $alignment->[$i] - 1 : $i - 1;
            my $to = $inv ? $i - 1 : $alignment->[$i] - 1;
            if ( scalar( @src_nodes ) <= $from || scalar( @tgt_nodes ) <= $to ) {
                log_warn "Sentence $sent_number: Alignment point $from-$to out of bounds";
            } else {
                $src_nodes[$from]->add_aligned_node( $tgt_nodes[$to], $direction );
            }
        }
    }
    if ( defined $bundles[0] ) {
        log_warn "Only aligned $sent_number sentences. ",
            "The document has " . scalar( @bundles ) . " more sentences";
    }
}

sub _store_bi_align {
    my ( $self, $document ) = @_;
    my $symalin_left_hdl = _my_save( "$mytmpdir/out.left" );
    my $symalin_right_hdl = _my_save( "$mytmpdir/out.right" );
    my $alileft_hdl = _my_open( "$mytmpdir/a-b.A3.final" );
    my $aliright_hdl = _my_open( "$mytmpdir/b-a.A3.final" );

    my @empty_lines; # lines that we should supply empty alignment for

    my @bundles = $document->get_bundles;
    # read MGiza outputs in both directions, prepare input for symal
    my $sent_number = 0;
    while ( ! eof $alileft_hdl ) {
        $sent_number++;
        my $bundle = shift @bundles;
        my ( $ok, $alithere, $aliback, $src_sent, $tgt_sent, $therescore, $backscore )
            = _read_bidirectional_align( $alileft_hdl, $aliright_hdl );
        if ( $ok ) {
            my @points_there = @$alithere;
            my @points_back = @$aliback;

            # write the normal symal input
            print $symalin_left_hdl "1\n";
            print $symalin_left_hdl "$#points_there $src_sent # ",
                join(" ", @points_there[1..$#points_there]), "\n";
            print $symalin_left_hdl "$#points_back $tgt_sent # ",
                join(" ", @points_back[1..$#points_back]), "\n";

            # write the reverse symal input
            print $symalin_right_hdl "1\n";
            print $symalin_right_hdl "$#points_back $tgt_sent # ",
                join(" ", @points_back[1..$#points_back]), "\n";
            print $symalin_right_hdl "$#points_there $src_sent # ",
                join(" ", @points_there[1..$#points_there]), "\n";

            # store alignment scores in the atree
            my $src_root = $bundle->get_zone( $self->from_language, $self->from_selector )->get_atree;
            my $tgt_root = $bundle->get_zone( $self->to_language, $self->to_selector )->get_atree;
            $src_root->set_attr( "giza_scores/counterpart.rf", $tgt_root->id );
            $src_root->set_attr( "giza_scores/therevalue", $therescore );
            $src_root->set_attr( "giza_scores/backvalue", $backscore );
        } else {
            push @empty_lines, $sent_number;
        }
    }
    close $symalin_left_hdl;
    close $symalin_right_hdl;
    close $alileft_hdl;
    close $aliright_hdl;

    # run symal and write the symm
    for my $sym ( @parsed_dir_or_sym ) {
        # we skip 'left'/'right' here, they were already output if user wanted them
        next if $sym eq "left" || $sym eq "right";
        $self->_run_symal( $sym, $document, @empty_lines );
    }
}

sub _run_symal {
    my ( $self, $sym, $document, @empty_lines ) = @_;

    # get symmetrization arguments
    my ( $reverse, $symal_args ) = _parse_dirsym( $sym );

    my $symal_outfile = "$mytmpdir/out.$sym";
    my $symal_infile = $reverse ? "$mytmpdir/out.right" : "$mytmpdir/out.right";

    # run symal
    log_info "Running symal for symmetrization '$sym'";
    my $symal = $self->mgizadir . '/bin/symal';
    _safesystem( "$symal $symal_args < $symal_infile > $symal_outfile" );

    # read its output and store it in Treex
    my $symal_outfile_hdl = _my_open( $symal_outfile );        
    my $sent_number = 0;
    my @bundles = $document->get_bundles;
    while ( <$symal_outfile_hdl> ) {
        chomp( my $line = $_ );
        $line =~ s/.*{##} //; # original sentences are printed first
        my $bundle = shift @bundles;
        $sent_number++;

        # skip over sentences with empty alignment
        while ( grep { $_ == $sent_number } @empty_lines ) {
            $sent_number++;
            $bundle = shift @bundles;
        }
        my $src_root = $bundle->get_zone( $self->from_language, $self->from_selector )->get_atree;
        my $tgt_root = $bundle->get_zone( $self->to_language, $self->to_selector )->get_atree;
        my @src_nodes = $src_root->get_descendants( { ordered => 1 } );
        my @tgt_nodes = $tgt_root->get_descendants( { ordered => 1 } );

        for my $point (split ' ', $line) {
            my ( $from, $to );
            if ( $reverse ) {
                ( $to, $from ) = split '-', $point;
            } else {
                ( $from, $to ) = split '-', $point;
            }
            if ( scalar( @src_nodes ) <= $from || scalar( @tgt_nodes ) <= $to ) {
                log_warn "Sentence $sent_number: Alignment point $from-$to out of bounds";
            } else {
                $src_nodes[$from]->add_aligned_node( $tgt_nodes[$to], $sym );
            }
        }
    }
}

sub _read_align {
    my $ali_hdl = shift;
    my ( $t1, $s1 );
    my @a = ();
    
    my $stats = <$ali_hdl>; ## header
    chomp( $s1 = <$ali_hdl> );
    chomp( $t1 = <$ali_hdl> );
    
    my $aliscore = undef;
    chomp $stats;
    $aliscore = $1 if $stats =~ m/ : (.+)$/;
    
    #get target statistics
    my $n = 1;
    $t1 =~ s/NULL \(\{(( \d+)*) \}\)//;
    while ( $t1 =~ s/(\S+) \(\{(( \d+)*) \}\)// ) {
        foreach $_ (split / /, $2) {
          next if $_ eq "";
          $a[$_] = $n;
        }
        $n++;
    }
    
    my @s1 = split / /, $s1;
    my $M = scalar @s1;
    
    for ( my $j = 1; $j < $M + 1; $j++ ) {
        $a[$j]=0 if !$a[$j];
    }
    
    return ( \@a, $aliscore );
}


sub _read_bidirectional_align {
    my ( $there_hdl, $back_hdl ) = @_;
    my ( $t1, $t2, $s1, $s2, $stats );
    my ( @a, @b );
    
    chomp( $stats = <$there_hdl> ); ## header
    chomp( $s1 = <$there_hdl> );
    chomp( $t1 = <$there_hdl> );
    my $aliscore1 = $1 if $stats =~ m/ : (.+)$/;
    
    chomp( $stats= <$back_hdl> ); ## header
    chomp( $s2= <$back_hdl> );
    chomp( $t2= <$back_hdl> );
    my $aliscore2 = $1 if $stats =~ m/ : (.+)$/;
    
    #get target statistics
    my $n = 1;
    $t1 =~ s/NULL \(\{(( \d+)*) \}\)//;
    while ( $t1 =~ s/(\S+) \(\{(( \d+)*) \}\)// ) {
        foreach $_ ( split / /, $2 ) {
          next if $_ eq "";
          $a[$_] = $n;
        }
        $n++;
    }
    
    my $m = 1;
    $t2 =~ s/NULL \(\{(( \d+)*) \}\)//;
    while ( $t2 =~ s/(\S+) \(\{(( \d+)*) \}\)// ) {
        foreach $_ ( split / /, $2 ) {
          next if $_ eq "";
          $b[$_] = $m;
        }
        $m++;
    }
    
    my @s1 = split / /, $s1;
    my $M = scalar @s1;
    my @s2 = split / /, $s2;
    my $N = scalar @s2;
    
    return ( 0, undef, undef, $s1, $s2, $aliscore1, $aliscore2 )
      if $m != ($M + 1) || $n != ($N + 1);
    
    for ( my $j = 1; $j < $m; $j++ ) {
        $a[$j] = 0 if ! $a[$j];
    }
    
    for ( my $i = 1; $i < $n; $i++ ) {
        $b[$i] = 0 if ! $b[$i];
    }
    
    return ( 1, \@a, \@b, $s1, $s2, $aliscore1, $aliscore2 );
}

sub _safesystem {
    log_info "Executing: @_";
    system(@_);
    if ($? == -1) {
        log_fatal "Failed to execute: @_\n  $!";
    }
    elsif ($? & 127) {
        log_fatal( sprintf "Execution of: @_\n  died with signal %d, %s coredump",
            ($? & 127),  ($? & 128) ? 'with' : 'without' );
    }
    else {
    my $exitcode = $? >> 8;
        log_info "Exit code: $exitcode" if $exitcode;
        return ! $exitcode;
    }
}

sub _my_open {
  my $f = shift;
  log_fatal "Not found: $f" if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file $f`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat $f |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat $f |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

sub _my_save {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDOUT, ":utf8");
    return *STDOUT;
  }

  my $opn;
  my $hdl;
  # file might not recognize some files!
  if ($f =~ /\.gz$/) {
    $opn = "| gzip -c > '$f'";
  } elsif ($f =~ /\.bz2$/) {
    $opn = "| bzip2 > '$f'";
  } else {
    $opn = ">$f";
  }
  open $hdl, $opn or die "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

1;

=head1 NAME 

=over

=item Treex::Block::Align::A::AlignMGiza

=back 

=head1 DESCRIPTION

Compute alignment of analytical trees using MGIZA++ using an existing model.

This module is based on gizawrapper.pl.

=head1 PARAMETERS

=over

=item C<from_language>

The target language. Required.

=item C<to_language>

The source language. Required.

=item C<dir_or_sym>

Comma delimited directions or symmetrizations of alignment. For direction, values "left"
and "right" are recognized. For symmetrizaton, use values "union", "intersection", "grow",
"grow-diag", "grow-diag-final", or "grow-diag-final-and". Default is "grow-diag-final".

=item C<align_attr>

The node attribute, over which to compute the alignment. Default is "lemma".

=item C<cpu_cores>

How many CPU cores should be used. Default is -1 (autodetect).

B<Caveats>: If more than one core is used, the results are not stable,
i.e. repeated runs can yield slightly different results
(presumably slightly worse than if running on one core only
but this has not yet been inspected thoroughly enough).
If this is an issue for you, make sure to always set C<cpu_cores=1>!

=item C<model>

Absolute path to model files for MGiza++.
Can be overridden by C<model_from_share>.

=item C<model_from_share>

Path to model files for MGiza++, relative to C<share/data/models/mgiza/>.
The model files are automatically downloaded if missing locally but available online.
Overrides C<model>.
Default is undef.

=back 

=head1 AUTHOR

Ales Tamchyna <a.tamchyna@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

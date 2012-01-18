package Treex::Block::Align::A::AlignMGiza;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use FileUtils;
use File::Temp;
use threads;

has from_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has align_attr => ( isa => 'Str', is => 'ro', default => 'lemma' );
has dir_or_sym => ( isa => 'Str', is => 'ro', default => 'grow-diag-final' );
has tmp_dir => ( isa => 'Str', is => 'ro', default => '/mnt/h/tmp' );
has cpu_cores => ( isa => 'Int', is => 'rw', default => '-1' ); # -1 means autodetect

# XXX replace with path in tectomt_shared
my $mgizadir = "/home/tamchyna/tectomt_devel/trunk/treex/lib/Treex/Block/Align/A/mgizapp/";

my $mkcls = "$mgizadir/bin/mkcls";
my $mgiza = "$mgizadir/bin/mgiza";
my $snt2cooc = "$mgizadir/bin/snt2cooc";
my $symal = "$mgizadir/bin/symal";
my $merge = "$mgizadir/scripts/merge_alignment.py";

my $mytmpdir;

sub process_document {
    my ( $self, $document ) = @_; 

    # create tempdir
    $mytmpdir = File::Temp::tempdir( "alignmgizaXXXXXX", DIR => $self->tmp_dir );
    log_info "Created temporary dir: $mytmpdir";

    # set number of cores
    if ( $self->cpu_cores == -1 ) {
        chomp(my $cores = `cat /proc/cpuinfo | grep CPU | wc -l`);
        $self->{cpu_cores} = $cores;
    }
    log_info "Using " . $self->cpu_cores . " cores";

    if ($self->dir_or_sym ne "left" && $self->dir_or_sym ne "right") {
    # XXX parallel processing does not work yet, may as well use all cores
#        $self->{cpu_cores} = $self->cpu_cores / 2; # we run 2 mgizas in parallel         
    }

    log_info "Writing document as plain text";

    # output sentences into plain text
    # XXX not parallel, not sure if Treex accessors are re-entrant
    _write_plain( $document, $self->from_language, $self->align_attr, "$mytmpdir/txt-a" );
    _write_plain( $document, $self->to_language, $self->align_attr, "$mytmpdir/txt-b" );

    log_info "Running mkcls";

    # create word classes
    _run_parallel(
        sub { _make_cls( "$mytmpdir/txt-a", "$mytmpdir/vcb-a.classes" ) },
        sub { _make_cls( "$mytmpdir/txt-b", "$mytmpdir/vcb-b.classes" ) }
    );

    log_info "Creating vocabulary files";

    # create vocabulary lists
    my ( $src_vcb, $tgt_vcb ) = _run_parallel(
        sub { _collect_vocabulary( "$mytmpdir/txt-a", "$mytmpdir/vcb-a" ) },
        sub { _collect_vocabulary( "$mytmpdir/txt-b", "$mytmpdir/vcb-b" ) }
    );

    # get symmetrization arguments
    my ( $alitype, $alidiag, $alifinal, $alifinaland ) = _parse_dirsym( $self->dir_or_sym );

    log_info "Running MGiza";

    # run mgiza (both ways if symmetrization is specified, not direction)
    if ( $self->dir_or_sym eq "left" ) {
        $self->_run_mgiza( $src_vcb, $tgt_vcb, 0 );
        $self->_store_uni_align( $document );
    } elsif ( $self->dir_or_sym eq "right" ) {
        $self->_run_mgiza( $tgt_vcb, $src_vcb, 1 );
        $self->_store_uni_align( $document );
    } else {
        # run mgiza in both directions and merge
        _run_parallel(
            sub { $self->_run_mgiza( $src_vcb, $tgt_vcb, 0 ) },
            sub { $self->_run_mgiza( $tgt_vcb, $src_vcb, 1 ) }
        );
        $self->_store_bi_align( $document );
    }
}

sub _write_plain {
    my ( $document, $language, $attr, $file ) = @_;
    my $hdl = _my_save( $file );
    for my $bundle( $document->get_bundles ) {
        my @nodes = $bundle->get_zone( $language )->get_atree->get_descendants();
        print $hdl join( " ", map { s/ /_/g; $_ } map { $_->get_attr( $attr ) } @nodes ), "\n";    
    }
    close $hdl;
}

sub _make_cls {
    my ( $src_file, $tgt_file ) = @_;
    _safesystem( "$mkcls -c50 -n2 -p$src_file -V$tgt_file opt" );
}

sub _collect_vocabulary {
    my ( $src_file, $tgt_file ) = @_;
    log_info "Collecting vocabulary for $src_file";
  
    my %count;
    my $src_hdl = _my_open( $src_file );
    while(<$src_hdl>) {
        chomp;
        foreach (split) { $count{$_}++; }
    }
    close $src_hdl;
  
    my %vcb;
    my $tgt_hdl = _my_save( $tgt_file );
    print $tgt_hdl "1\tUNK\t0\n";
    my $id = 2;
    foreach my $word (sort {$count{$b}<=>$count{$a}} keys %count) {
        my $count = $count{$word};
        printf $tgt_hdl "%d\t%s\t%d\n",$id,$word,$count;
        $vcb{$word} = $id;
        $id++;
    }
    close $tgt_hdl;
    
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
    my $alidiag = "no";
    my $alifinal = "no";
    my $alifinaland = "no";
    if ($dirsym eq "left" || $dirsym eq "right") {
        # ok
    } elsif ($dirsym eq "int" || $dirsym eq "intersect") {
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
    return ( $alitype, $alidiag, $alifinal, $alifinaland );
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
    _safesystem( "$snt2cooc $cooc_file $mytmpdir/vcb-$a $mytmpdir/vcb-$b $corpus" );

    # generate options for MGiza
    my %mgiza_options = ( 
        p0 => .999 ,
        m1 => 5 , 
        m2 => 0 , 
        m3 => 3 , 
        m4 => 3 , 
        nodumps => 0 , 
        onlyaldumps => 0 , 
        nsmooth => 4 , 
        model1dumpfrequency => 1,
        model4smoothfactor => 0.4 ,
        s => "$mytmpdir/vcb-$b",
        t => "$mytmpdir/vcb-$a",
        c => $corpus,
        ncpu => $self->cpu_cores,
        CoocurrenceFile => $cooc_file,
        o => "$mytmpdir/$a-$b"
    );

    my $options_str;
    map { $options_str .= " -$_ $mgiza_options{$_}" } sort keys %mgiza_options;

    # run mgiza
    _safesystem( "$mgiza $options_str" );

    # merge alignment parts
    _safesystem( "$merge $mytmpdir/$a-$b.A3.final.part* > $mytmpdir/$a-$b.A3.final" );

    # remove alignment parts
    _safesystem( "rm -f $mytmpdir/$a-$b.A3.final.part*" );
}

sub _store_uni_align {
    my ( $self, $document ) = @_;
    my ( $a, $b );
    my $inv = ( $self->dir_or_sym eq "left" ) ? 0 : 1;
    if ( ! $inv ) {
        $a = 'a';
        $b = 'b';
    } else { # inverse alignment
        $a = 'b';
        $b = 'a';
    }
    my $ali_hdl = _my_open( "$mytmpdir/$a-$b.A3.final" );
    my @bundles = $document->get_bundles;
    my $index = 0;
    while ( ! eof $ali_hdl ) {
        $index++;
        my $bundle = shift @bundles;
        my $src_root = $bundle->get_zone( $self->from_language )->get_atree;
        my $tgt_root = $bundle->get_zone( $self->to_language )->get_atree;
        my ( $alignment, $aliscore ) = _read_align( $ali_hdl );
        $src_root->set_attr( "giza_scores/counterpart.rf", $tgt_root->id );
        my $score_direction = $inv ? "back" : "there"; # XXX is this correct?
        $src_root->set_attr( "giza_scores/" . $score_direction .  "value", $aliscore );
        my @src_nodes = $src_root->get_descendants( { ordered => 1 } );
        my @tgt_nodes = $tgt_root->get_descendants( { ordered => 1 } );
        for ( my $i = 0; $i < scalar @$alignment; $i++ ) {
            next if ! defined $alignment->[$i] || $alignment->[$i] == 0;
            my $from = $inv ? $alignment->[$i] - 1 : $i - 1;
            my $to = $inv ? $i - 1 : $alignment->[$i] - 1;
            $src_nodes[$from]->add_aligned_node( $tgt_nodes[$to], $self->dir_or_sym );
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
    my $c = 1;
    
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
    
    return ( 0, undef, undef, $s1, $s2, $c, $aliscore1, $aliscore2 )
      if $m != ($M + 1) || $n != ($N + 1);
    
    for ( my $j = 1; $j < $m; $j++ ) {
        $a[$j] = 0 if ! $a[$j];
    }
    
    for ( my $i = 1; $i < $n; $i++ ) {
        $b[$i] = 0 if ! $b[$i];
    }
    
    return ( 1, \@a, \@b, $s1, $s2, $c, $aliscore1, $aliscore2 );
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

sub _run_parallel {
    my ( $first, $second ) = @_;
#     my $thread_first = threads->new( $first );
#     my $result_second = &$second;
#     my $result_first = $thread_first->join();
    my $result_first = &$first; # I get a segfault when using threads
    my $result_second = &$second;
    return ( $result_first, $result_second );
}

1;

=head1 NAME 

=over

=item Treex::Block::Align::A::AlignMGiza

=back 

=head1 DESCRIPTION

Compute alignment of analytical trees using MGIZA++.
Optionally, train incrementally using a previous model, or store the newly computed model.

This module is based on gizawrapper.pl.

=head1 PARAMETERS

=over

=item C<from_language>

The target language. Required.

=item C<to_language>

The source language. Required.

=item C<dir_or_sym>

Direction or symmetrization of alignment. For direction, values "left" and "right" are recognized.
For symmetrizaton, use values "union", "intersection", "grow", "grow-diag", "grow-diag-final",
or "grow-diag-final-and". Default is "grow-diag-final".

=item C<align_attr>

The node attribute, over which to compute the alignment. Default is "lemma".

=item C<cpu_cores>

How many CPU cores should be used. Default is -1 (autodetect).

=back 

=head1 AUTHOR

Ales Tamchyna <a.tamchyna@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

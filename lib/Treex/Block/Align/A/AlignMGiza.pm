package Treex::Block::Align::A::AlignMGiza;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use FileUtils;
use threads;

has from_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has align_attr => ( isa => 'Str', is => 'ro', default => 'lemma' );
has dir_or_sym => ( isa => 'Str', is => 'ro', default => 'grow-diag-final' );
has cpu_cores => ( isa => 'Int', is => 'rw', default => '-1' ); # -1 means autodetect

# XXX replace with path in tectomt_shared
my $mgizadir = "/home/tamchyna/tectomt_devel/trunk/treex/lib/Treex/Block/Align/A/mgizapp/";

my $mkcls = "$mgizadir/bin/mkcls";
my $giza = "$mgizadir/bin/mgiza";
my $snt2cooc = "$mgizadir/bin/snt2cooc";
my $symal = "$mgizadir/bin/symal";
my $merge = "$mgizadir/scripts/merge_alignment.py";

my $mytmpdir;

sub process_document {
    my ( $self, $document ) = @_; 

    # create tempdir
    $mytmpdir = get_unique_temporary_filename( "alignmgiza" );
    mkdir $mytmpdir;

    # set number of cores
    if ( $self->cpu_cores == -1 ) {
        chomp(my $cores =  `cat /proc/cpuinfo | grep CPU | wc -l`);
        $self->cpu_cores($cores);
    }
    if ($self->dir_or_sym ne "left" && $self->dir_or_sym ne "right") {
        $self->cpu_cores( $self->cpu_cores / 2 ); # we run 2 mgizas in parallel         
    }

    # output sentences into plain text
    # XXX not parallel, not sure if Treex accessors are re-entrant
    _write_plain( $document, $self->from_language, $self->align_attr, "$mytmpdir/txt-a" );
    _write_plain( $document, $self->to_language, $self->align_attr, "$mytmpdir/txt-b" );

    # create word classes
    _run_parallel(
        sub { _make_cls( "$mytmpdir/txt-a", "$mytmpdir/vcb-a.classes" ) },
        sub { _make_cls( "$mytmpdir/txt-b", "$mytmpdir/vcb-b.classes" ) }
    );

    # create vocabulary lists
    my ( $src_vcb, $tgt_vcb ) = _run_parallel(
        sub { _collect_vocabulary( "$mytmpdir/txt-a", "$mytmpdir/vcb-a" ) },
        sub { _collect_vocabulary( "$mytmpdir/txt-b", "$mytmpdir/vcb-b" ) }
    );

    # get symmetrization arguments
    my ( $alitype, $alidiag, $alifinal, $alifinaland ) = _parse_dirsym( $self->dir_or_sym );

    # run mgiza (both ways if symmetrization is specified, not direction)
    if ( $self->align_attr eq "left" ) {
        $self->_run_mgiza( $src_vcb, $tgt_vcb, 0 );
    } elsif (  $self->align_attr eq "right" ) {
        $self->_run_mgiza( $tgt_vcb, $src_vcb, 1 );
    } else {
        # run mgiza in both directions and merge
        _run_parallel(
            sub { $self->_run_mgiza( $src_vcb, $tgt_vcb, 0 ) },
            sub { $self->_run_mgiza( $tgt_vcb, $src_vcb, 1 ) }
        );
    }
}

sub _write_plain {
    my ( $document, $language, $attr, $file ) = @_;
    my $hdl = my_open( $file );
    for my $bundle( $document->get_bundles ) {
        my @nodes = $bundle->get_zone( $language )->get_atree->get_descendants();
        print $hdl join( " ", map { $_->get_attr( $attr ) } @nodes ), "\n";    
    }
    close $hdl;
}

sub _make_cls {
    my ( $src_file, $tgt_file ) = @_;
    _safesystem( "$mkcls -c50 -n2 -p$src_file -V$tgt_file opt >&2" );
}

sub _collect_vocabulary {
    my ( $src_file, $tgt_file ) = @_;
    log_info "Collecting vocabulary for $src_file";
  
    my %count;
    my $src_hdl = my_open( $src_file );
    while(<$src_hdl>) {
        chomp;
        foreach (split) { $count{$_}++; }
    }
    close $src_hdl;
  
    my %vcb;
    my $tgt_hdl = my_open( $tgt_file );
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
    my $out_hdl = my_open( $outfile );
    my $src_hdl = my_open( $src_txt );
    my $tgt_hdl = my_open( $tgt_txt );

    while ( chomp( my $src_line = <$src_hdl> ) ) {
        chomp( my $tgt_line = <$tgt_hdl> );
        my @src_numbers = map { $src_vcb->{$_} } split / /, $src_line;
        my @tgt_numbers = map { $tgt_vcb->{$_} } split / /, $tgt_line;
        print $out_hdl join( " ", @src_numbers ), "\t", ( " ", @tgt_numbers ), "\n";
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
    _safesystem( "$snt2cooc $mytmpdir/vcb-$a $mytmpdir/vcb-$b $corpus > $cooc_file" );

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
        s => "$mytmpdir/vcb-$a",
        t => "$mytmpdir/vcb-$b",
        c => $corpus,
        ncpu => $self->cpu_cores,
        CoocurrenceFile => $cooc_file,
        o => "$mytmpdir/$a-$b.A3.final"
    );

    my $options_str;
    map { $options_str .= " -$_ $mgiza_options{$_}" } sort keys %mgiza_options;
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

sub _run_parallel {
    my ( $first, $second ) = @_;
    my $thread_first = threads->new( $first );
    my $result_second = &$second;
    my $result_first = $thread_first->join();
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

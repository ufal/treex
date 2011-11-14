package Treex::Block::Align::A::AlignMGiza;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use FileUtils;

has from_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has align_attr => ( isa => 'Str', is => 'ro', default => 'lemma' );
has tmpdir => ( isa => 'Str', is => 'ro', default => $ENV{TMT_TEMP} );

my $mgizadir = "/home/tamchyna/tectomt_devel/trunk/treex/lib/Treex/Block/Align/A/mgizapp/";

my $mkcls = "$mgizadir/bin/mkcls";
my $giza = "$mgizadir/bin/mgiza";
my $snt2cooc = "$mgizadir/bin/snt2cooc";
my $symal = "$mgizadir/bin/symal";
my $merge = "$mgizadir/scripts/merge_alignment.py";

sub process_document {
    my ( $self, $document ) = @_; 
    my $mytmpdir = get_unique_temporary_filename( "alignmgiza" );
    _write_plain( $document, $self->{from_language}, $self->{align_attr}, "$mytmpdir/txt-a" );
    _write_plain( $document, $self->{to_language}, $self->{align_attr}, "$mytmpdir/txt-b" );
    _make_cls( "$mytmpdir/txt-a", "$mytmpdir/vcb-a.classes" );
    _make_cls( "$mytmpdir/txt-b", "$mytmpdir/vcb-b.classes" );
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

return 1;

package Treex::Tools::Parser::MST;

use Moose;
use MooseX::FollowPBP;

use ProcessUtils;
use File::Java;
use DowngradeUTF8forISO2;

has model      => (isa => 'Str', is => 'rw', required => 1);
has memory     => (isa => 'Str', is => 'rw', default => '1800m');
has order      => (isa => 'Int', is => 'rw', default => 2);
has decodetype => (isa => 'Str', is => 'rw', default => 'non-proj');
has robust     => (isa => 'Bool', is => 'r', default => 0);

my @all_javas;  # PIDs of java processes

sub BUILD {
    my ( $self ) = @_;

    #to be changed
    my $bindir = "$ENV{TMT_ROOT}/libs/other/Parser/MST/mstparser-0.4.3b";
    die "Missing $bindir\n" if !-d $bindir;
    
    #TODO this should be done better
    my $redirect = Report::get_error_level() == 1 ? '' : '2>/dev/null';

    # We communicate with the parser in ISO-8859-2. In principle, any encoding is
    # fine (e.g. utf8, as long as the binmode of bipipe corresponds to the
    # encoding given as arg 2 to server.PerlParser.

    # portable invocation of java vm
    my $javabin = File::Java->javabin();
    my $cp = File::Java->cp( "$bindir/output/mstparser.jar", "$bindir/lib/trove.jar" );
    # all paths/dirs have to be formatted according to platform
    my $model_name = File::Java->path_arg($self->{model});

    my $command = 'java'#$javabin
        . " -Xmx" . $self->{memory}
        . " -cp $cp mstparser.DependencyParser test"
        . " order:" . $self->{order}
        . " decode-type:" . $self->{decodetype}
        . " server-mode:true print-scores:true model-name:$model_name 2>/dev/null";


    $SIG{PIPE} = 'IGNORE';  # don't die if parser gets killed
    my ( $reader, $writer, $pid )
        = ProcessUtils::bipipe( $command, ":encoding(iso-8859-2)" );

    $self->{reader} = $reader;
    $self->{writer} = $writer;
    $self->{pid}    = $pid;

    push @all_javas, $self;

    return;
}

sub parse_sentence {

    my ( $self, $forms_rf, $tags_rf ) = @_;

    if ( ref($forms_rf) ne "ARRAY" or ref($tags_rf) ne "ARRAY" ) {
        Report::fatal('Both arguments must be array references.');
    }

    if ( $#{$forms_rf} != $#{$tags_rf} or @$forms_rf == 0 ) {
        Report::warn "FORMS: @$forms_rf\n";
        Report::warn "TAGS:  @$tags_rf\n";
        Report::fatal('Both arguments must be references to nonempty arrays of equal length.');
    }

    if ( my @ret = grep { $_ =~ /^\s+$/ } ( @{$forms_rf}, @{$tags_rf} ) ) {
        Report::data("@ret");
        Report::fatal('Elements of argument arrays must not be empty and must not contain white-space characters');
    }

    if ( @{$tags_rf} == 1 ) {
        # single-word sentences are not passed to parser at all
        return ( [0], ['Pred'] );
    }

    my @parents;
    my @afuns;
    my @scores;

    if (!$self->{robust}) {

        my $writer = $self->{writer};
        my $reader = $self->{reader};
        Report::fatal("Treex::Tools::Parser::MST: unexpected status") if (!defined $reader || !defined $writer);
  
        print $writer join( "\t", @$forms_rf ) . "\n";
        print $writer join( "\t", @$tags_rf ) . "\n";
        
        $_ = <$reader>;
        Report::fatal("Treex::Tools::Parser::MST returned nothing") if (!defined $_);
        chomp;
        Report::fatal("Treex::Tools::Parser::MST failed (FAIL message was returned) on sentence '" . join(" ", @$forms_rf) . "'") if ($_ !~ /^OK/);
        $_ = <$reader>; # forms
        $_ = <$reader>; # lemmas
        $_ = <$reader>; # afuns
        Report::fatal("Treex::Tools::Parser::MST wrote unexpected number of lines") if (!defined $_);
        chomp;
        @afuns = split /\t/;
        @afuns = map { s/^.*no-type.*$/Atr/; $_ } @afuns;
        $_ = <$reader>; # parents
        Report::fatal("Treex::Tools::Parser::MST wrote unexpected number of lines") if (!defined $_);
        chomp;
        @parents = split /\t/;
        $_ = <$reader>; # blank line after a valid parse
        $_ = <$reader>; # scoreMatrix
        Report::fatal("Treex::Tools::Parser::MST wrote unexpected number of lines") if (!defined $_);
        chomp;
        @scores = split /\s/;

        # back to the matrix of scores
        shift @scores;
        my @matrix;
        foreach my $i (0 .. $#parents) {
            foreach my $j ( 0 .. $#parents) {
                $matrix[$i][$j] = shift @scores;
            }
        }

        return ( \@parents, \@afuns, \@matrix );
    }

    # OBO'S ROBUST VARIANT
    my $attempts = 3;
    my $first_attempt = 1;
    my $ok = 0;
    my ( @parents, @afuns );
    RETRY: while (!$ok && $attempts) {
      Report::warn "Treex::Tools::Parser::MST: $attempts attempts remaining" if !$first_attempt;
      $attempts--;
      $first_attempt = 0;

      if (!defined $self->{writer}) {
        Report::warn "Treex::Tools::Parser::MST: Reinitializing";
        my $newself = Treex::Tools::Parser::MST->new({model => $self->{model}, memory => $self->{memory}, order => $self->{order}, decodetype => $self->{decodetype}});
        foreach my $attr (qw(reader writer pid)) {
          $self->{$attr} = $newself->{$attr};
        }
      }

      my $writer = $self->{writer};
      my $reader = $self->{reader};
  
      # We deliberately approximate e.g. curly quotes with plain ones, the final
      # encoding of the pipes is not relevant, see the constructor (new) above.
      print $writer
          DowngradeUTF8forISO2::downgrade_utf8_for_iso2( join( "\t", @$forms_rf ) ) . "\n";
      print $writer
          DowngradeUTF8forISO2::downgrade_utf8_for_iso2( join( "\t", @$tags_rf ) ) . "\n";
  
      $_ = <$reader>;
      if (!defined $_) {
        Report::info("Parser::MST::English: java parser died, got no parse");
        $self->{writer} = undef; # ask for reinit
        goto RETRY;
      }
      chomp;
      if (/^FAIL/) {
          Report::info("Parser::MST::English refused to parse the sentence. Building flat tree. Parser error: $_");
          @parents = map {0} @$forms_rf;
          @afuns   = map {"ExD"} @$forms_rf;
          $ok = 1;
      }
      elsif ( $_ eq "OK" ) {
          $_ = <$reader>; # forms?
          $_ = <$reader>; # lemmas?
          $_ = <$reader>; # afuns
          if (!defined $_) {
            Report::info("Parser::MST::English: java parser died, got no parse");
            $self->{writer} = undef; # ask for reinit
            goto RETRY;
          }
          chomp;
          @afuns = split /\t/;
          $_     = <$reader>;  # parents
          if (!defined $_) {
            Report::info("Parser::MST::English: java parser died, got no parse");
            $self->{writer} = undef; # ask for reinit
            goto RETRY;
          }
          chomp;
          @parents = split /\t/;
  
          @afuns = map { s/^.*no-type.*$/Atr/; $_ } @afuns;
          $ok = 1;
  
          $_ = <$reader>;        #Blank line after a valid parse
      }
      else {
          Report::fatal("Parser::MST::English: unexpected status: $_");
      }
    }
    if (!$ok) {
          Report::info("Parser::MST::English failed to parse the sentence after several attempts. Building flat tree.");
          @parents = map {0} @$forms_rf;
          @afuns   = map {"ExD"} @$forms_rf;
    }
    return ( \@parents, \@afuns );
}

# ----------------- cleaning up ------------------

END {
    foreach my $java (@all_javas) {
        close( $java->{writer} );
        close( $java->{reader} );
        ProcessUtils::safewaitpid( $java->{pid} );
    }
}

1;

__END__


=pod

=head1 NAME

Treex::Tools::Parser::MST


=head1 SYNOPSIS


 use Treex::Tools::Parser::MST

 my @wordforms = qw(A       group   of      investors       recently        bought  the     remaining       assets  .);
 my @tags = qw(D       N       I       N               R               V       D       V               N   .);

 my $parser = Treex::Tools::Parser::MST->new({model => 'conll_mcd_order2_0.01.model',
                                              memory => '1000m', 
                                              order => 2,
                                              decodetype => 'non-proj'});

 my ($parents_rf,$afuns_rf) = $parser->parse_sentence(\@wordforms,\@tags);

 for my $i (0..$#wordforms) {
   print $i + 1 . ": wordform=$wordforms[$i]\tparent=$parents_rf->[$i]\tafun=$afuns_rf->[$i]\n";
 }


=head1 DESCRIPTION

Perl wrapper for Ryan McDonnald's Maximum Spanning Tree parser 0.4.3b.
When being used, it executes a Java Server and loads the parser model.

=head2 CONSTRUCTOR


=over 4


=item  my $parser = Treex::Tools::Parser::MST->new({model => $model});

Parameter 'model' is required and specifies the path to the model.

=back


=head2 METHODS

=over 4

=item  my ($parents_rf,$afuns_rf) = $parser->parse_sentence(\@wordforms,\@tags);

References to arrays of word forms and morphological tags are given
as arguments. References to arrays of parent indices (0 stands for artifical root)
and analytical functions are returned.

=back


=head1 TODOs




=head1 AUTHORS

Vaclav Novak, Zdenek Zabokrtsky, Ondrej Bojar, David Marecek

# Copyright 2008-2010 Vaclav Novak, Zdenek Zabokrtsky, Ondrej Bojar, David Marecek

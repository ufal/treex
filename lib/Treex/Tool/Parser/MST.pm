package Treex::Tool::Parser::MST;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Core::Resource;
use ProcessUtils;
use DowngradeUTF8forISO2;

with 'Treex::Tool::Parser::Role';
with 'Treex::Service::Role'
  if Treex::Core::Config->use_services;

has model      => ( isa => 'Str',  is => 'rw', required => 1 );
has memory     => ( isa => 'Str',  is => 'rw', default  => '1800m' );
has order      => ( isa => 'Int',  is => 'rw', default  => 2 );
has decodetype => ( isa => 'Str',  is => 'rw', default  => 'non-proj' );
has robust     => ( isa => 'Bool', is => 'ro', default  => 0 );

# other possible values: '0.5.0'
has version		=>	(isa => 'Str', is => 'ro', default => '0.4.3b');

my @all_javas;    # PIDs of java processes

sub initialize {
    my $self = shift;
    my $tool_path  = 'installed_tools/parser/mst/' . $self->version;
    my $jar_path   = require_file_from_share("$tool_path/mstparser.jar");
    my $trove_path = require_file_from_share("$tool_path/lib/trove.jar");

    #TODO this should be done better
    my $redirect = Treex::Core::Log::get_error_level() eq 'DEBUG' ? '' : '2>/dev/null';

    my $cp = join($^O =~ /Win32|OS2/ ? ';' : ':', $jar_path, $trove_path );
    my $model = $self->model;
    log_fatal "$model model for MST does not exist." if !-f $model;

	my @command;

    # TODO all paths/dirs have to be formatted according to platform
    # $model = File::Java->path_arg( $model );
	if ($self->version eq '0.4.3b') {
	    @command    = ('java'
	        , "-Xmx" . $self->memory
	        , "-cp", $cp, "mstparser.DependencyParser", "test"
	        , "order:" . $self->order
	        , "decode-type:" . $self->decodetype
	        , "server-mode:true", "print-scores:true", "model-name:$model", $redirect);
	}
	elsif ($self->version eq '0.5.0') {
	    @command    = ('java'
	        , "-Xmx" . $self->memory
	        , "-cp", $cp, "mstparser.DependencyParser", "test"
	        , "order:" . $self->order
	        , "decode-type:" . $self->decodetype
#	        , "server-mode:true", "confidence-estimation:'KDFix*0.05*50', "model-name:$model", "format:MST", $redirect);
	        , "server-mode:true", "model-name:$model", "format:MST", $redirect);
	}


    # We communicate with the parser in ISO-8859-2. In principle, any encoding is
    # fine (e.g. utf8, as long as the binmode of bipipe corresponds to the
    # encoding given as arg 2 to server.PerlParser.
    $SIG{PIPE} = 'IGNORE';                                   # don't die if parser gets killed
    my ( $reader, $writer, $pid )
        = ProcessUtils::bipipe_noshell( ":encoding(iso-8859-2)", @command );


    $self->{reader} = $reader;
    $self->{writer} = $writer;
    $self->{pid}    = $pid;

    # The following test must be done because of the lazy loading of the model
    my @test_forms = qw(This is a test sentence .);
    my @test_tags  = qw(X X X X X X);
    $self->parse_sentence( \@test_forms, \@test_tags );

    push @all_javas, $self;

    return;
}

sub parse_sentence { shift->process(@_) }

sub process {

    my ( $self, $forms_rf, $tags_rf ) = @_;

    if ( ref($forms_rf) ne "ARRAY" or ref($tags_rf) ne "ARRAY" ) {
        log_fatal('Both arguments must be array references.');
    }

    if ( $#{$forms_rf} != $#{$tags_rf} or @$forms_rf == 0 ) {
        log_warn "FORMS: @$forms_rf\n";
        log_warn "TAGS:  @$tags_rf\n";
        log_fatal('Both arguments must be references to nonempty arrays of equal length.');
    }

    if ( my @ret = grep { $_ =~ /^\s+$/ } ( @{$forms_rf}, @{$tags_rf} ) ) {
        log_debug("@ret");
        log_fatal('Elements of argument arrays must not be empty and must not contain white-space characters');
    }

    if ( @{$tags_rf} == 1 ) {

        # single-word sentences are not passed to parser at all
        return ( [0], ['Pred'] );
    }

    my ( @parents, @afuns, @matrix, $writer, $reader );

    # 0.5.0
    my @conf_scores = map {0} @$forms_rf;

    if ( !$self->{robust} ) {
        $writer = $self->{writer};
        $reader = $self->{reader};
        log_fatal("Treex::Tool::Parser::MST: unexpected status") if ( !defined $reader || !defined $writer );
        print $writer DowngradeUTF8forISO2::downgrade_utf8_for_iso2( join( "\t", @$forms_rf ) ) . "\n";
        print $writer DowngradeUTF8forISO2::downgrade_utf8_for_iso2( join( "\t", @$tags_rf ) ) . "\n";

        #        print $writer join( "\t", @$forms_rf ) . "\n";
        #        print $writer join( "\t", @$tags_rf ) . "\n";
        $_ = <$reader>;
        log_fatal("Treex::Tool::Parser::MST returned nothing") if ( !defined $_ );
        chomp;
        if ( $_ !~ /^OK|^\d+\s+OK/ ) {
            log_warn("Treex::Tool::Parser::MST failed (FAIL message was returned) on sentence. Building flat tree.'");
            @parents = map {0} @$forms_rf;
            @afuns   = map {"ExD"} @$forms_rf;
            foreach my $i ( 0 .. @$forms_rf ) {
                foreach my $j ( 0 .. @$forms_rf ) {
                    $matrix[$j][$i] = 0;
                }
            }
        }
        else {
            $_ = <$reader>;    # forms
            $_ = <$reader>;    # pos
            $_ = <$reader>;    # afuns
            log_fatal("Treex::Tool::Parser::MST wrote unexpected number of lines") if ( !defined $_ );
            chomp;
            @afuns = split /\t/;
            @afuns = map { s/^.*no-type.*$/Atr/; $_ } @afuns;
            $_     = <$reader>;                                 # parents
            log_fatal("Treex::Tool::Parser::MST wrote unexpected number of lines") if ( !defined $_ );
            chomp;
            @parents = split /\t/;
            if ($self->version eq '0.4.3b') {
	            $_       = <$reader>;                               # blank line after a valid parse
	            $_       = <$reader>;                               # scoreMatrix
	            log_fatal("Treex::Tool::Parser::MST wrote unexpected number of lines") if ( !defined $_ );
	            chomp;
	            my @scores = split( /\s/ );

	            # back to the matrix of scores
	            shift @scores;

	            foreach my $i ( 0 .. @parents ) {
	                foreach my $j ( 0 .. @parents ) {
	                    $matrix[$j][$i] = shift @scores;
	                }
	            }

	            # we don't want scores for root
	            shift @matrix;
            }
            elsif ($self->version eq '0.5.0') {
#	            $_ = <$reader>;    # conf scores
#            	chomp;
#            	@conf_scores = split /\t/;
	            $_ = <$reader>;    # blank line
            }
        }
        return ( \@parents, \@afuns, \@matrix ) if $self->version eq '0.4.3b';
        return ( \@parents, \@afuns, \@conf_scores ) if $self->version eq '0.5.0';
    }

    # OBO'S ROBUST VARIANT
    my $attempts      = 3;
    my $first_attempt = 1;
    my $ok            = 0;
    RETRY: while ( !$ok && $attempts ) {
        log_warn "Treex::Tool::Parser::MST: $attempts attempts remaining" if !$first_attempt;
        $attempts--;
        $first_attempt = 0;

        if ( !defined $self->{writer} ) {
            log_warn "Treex::Tool::Parser::MST: Reinitializing";
            my $newself = Treex::Tool::Parser::MST->new( { model => $self->{model}, memory => $self->{memory}, order => $self->{order}, decodetype => $self->{decodetype} } );
            foreach my $attr (qw(reader writer pid)) {
                $self->{$attr} = $newself->{$attr};
            }
        }

        $writer = $self->{writer};
        $reader = $self->{reader};

        # We deliberately approximate e.g. curly quotes with plain ones, the final
        # encoding of the pipes is not relevant, see the constructor (new) above.
        print $writer
            DowngradeUTF8forISO2::downgrade_utf8_for_iso2( join( "\t", @$forms_rf ) ) . "\n";
        print $writer
            DowngradeUTF8forISO2::downgrade_utf8_for_iso2( join( "\t", @$tags_rf ) ) . "\n";

        $_ = <$reader>;
        if ( !defined $_ ) {
            log_info("Parser::MST::English: java parser died, got no parse");
            $self->{writer} = undef;    # ask for reinit
            goto RETRY;
        }
        chomp;
        if (/^FAIL/) {
            log_info("Parser::MST::English refused to parse the sentence. Building flat tree. Parser error: $_");
            @parents = map {0} @$forms_rf;
            @afuns   = map {"ExD"} @$forms_rf;
            $ok      = 1;
        }
        elsif ( $_ eq "OK" ) {
            $_ = <$reader>;             # forms?
            $_ = <$reader>;             # lemmas?
            $_ = <$reader>;             # afuns
            if ( !defined $_ ) {
                log_info("Parser::MST::English: java parser died, got no parse");
                $self->{writer} = undef;    # ask for reinit
                goto RETRY;
            }
            chomp;
            @afuns = split /\t/;
            $_     = <$reader>;             # parents
            if ( !defined $_ ) {
                log_info("Parser::MST::English: java parser died, got no parse");
                $self->{writer} = undef;    # ask for reinit
                goto RETRY;
            }
            chomp;
            @parents = split /\t/;

            @afuns = map { s/^.*no-type.*$/Atr/; $_ } @afuns;
            $ok = 1;

            $_ = <$reader>;                 #Blank line after a valid parse
        }
        else {
            log_fatal("Parser::MST::English: unexpected status: $_");
        }
    }
    if ( !$ok ) {
        log_info("Parser::MST::English failed to parse the sentence after several attempts. Building flat tree.");
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
        kill(9, $java->{pid}); #Needed on Windows 
        ProcessUtils::safewaitpid( $java->{pid} );
    }
}

1;

__END__

=head1 NAME

Treex::Tool::Parser::MST

=head1 SYNOPSIS

 # ***********
 # Example 1: (uses MST version 0.4.3b)
 # ***********
 use Treex::Tool::Parser::MST

 my @wordforms = qw(A group of investors recently bought the remaining assets .);
 my @tags      = qw(D N     I  N         R        V      D   V         N      .);

 my $parser = Treex::Tool::Parser::MST->new({model => $path_to . 'conll_mcd_order2_0.01.model',
                                              memory => '1000m',
                                              order => 2,
                                              decodetype => 'non-proj'});

 my ($parents_rf,$afuns_rf) = $parser->parse_sentence(\@wordforms,\@tags);

 for my $i (0..$#wordforms) {
   print $i + 1 . ": wordform=$wordforms[$i]\tparent=$parents_rf->[$i]\tafun=$afuns_rf->[$i]\n";
 }

 # ***********
 #  Example 2: (uses MST version 0.5.0 and prints confidence scores)
 # ***********
 my $v = '0.5.0';
 my $path_to = 'news_mst_v0.5.0_order2_non-proj.model';
 my $parser = Treex::Tool::Parser::MST->new({model => $path_to,
                                              memory => '1000m',
                                              order => 2,
                                              decodetype => 'non-proj',
                                               version => $v});
 my ($parents_rf,$afuns_rf, $conf_rf) = $parser->parse_sentence(\@wordforms,\@tags);

 for my $i (0..$#wordforms) {
     print $i + 1 . ": wordform=$wordforms[$i]\tparent=$parents_rf->[$i]\tafun=$afuns_rf->[$i]\tconf=$conf_rf->[$i]\n";
 }

=head1 DESCRIPTION

Perl wrapper for Ryan McDonald's Maximum Spanning Tree parser 0.4.3b/0.5.0.
When being used, it executes a Java Server and loads the parser model.



=head2 CONSTRUCTOR


=over 4


=item  my $parser = Treex::Tool::Parser::MST->new({model => $model});

Parameter 'model' is required and specifies the path to the model.



=back

=head2 PARAMETERS

=over 4

=item version

If the 'version' is '0.4.3b' (default), the parser returns scores extracted from MIRA.

If the 'version' is '0.5.0', the parser returns confidence scores (probability like measures) for each edges in the sentence.

=back


=head2 METHODS

=over 4

=item  my ($parents_rf,$afuns_rf) = $parser->parse_sentence(\@wordforms,\@tags);

References to arrays of word forms and morphological tags are given
as arguments. References to arrays of parent indices (0 stands for artifical root)
and analytical functions are returned.


=item  my ($parents_rf,$afuns_rf, $conf_rf) = $parser->parse_sentence(\@wordforms,\@tags);

Returns reference to confidence score for each edges in addition to parents and afuns of a given sentence. The constructor must have been initiated with '0.5.0' for the 'version' parameter.


=back


=head1 SEE ALSO

L<Treex::Block::W2A::ParseMST>

=head1 AUTHORS

Vaclav Novak, Zdenek Zabokrtsky, Ondrej Bojar, David Marecek, Martin Popel

# Copyright 2008-2012 UFAL

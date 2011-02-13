package Treex::Core::Run;
use Treex::Moose;
use Treex::Core;
use MooseX::SemiAffordanceAccessor;
with 'MooseX::Getopt';

has 'save' => (
    traits        => ['Getopt'],
    cmd_aliases   => 's',
    is            => 'rw', isa => 'Bool', default => 0,
    documentation => 'save all documents',
);

has 'quiet' => (
    traits      => ['Getopt'],
    cmd_aliases => 'q',
    is          => 'rw', isa => 'Bool', default => 0,
    trigger => sub { Treex::Core::Log::set_error_level('FATAL'); },
    documentation => q{TODO don't print any TMT-INFO messages},
);

has 'lang' => (
    traits      => ['Getopt'],
    cmd_aliases => 'language',
    is          => 'rw', isa => 'LangCode',
    documentation => q{shortcut for adding "SetGlobal language=xy" at the beginning of the scenario},
);

#has 'verbose' =

has 'filelist' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'l',
    is            => 'rw', isa => 'Str',
    documentation => 'TODO load a list of treex files from a file',
);

has 'filenames' => (
    traits => ['NoGetopt'],
    is => 'rw',
    isa => 'ArrayRef[Str]',
    documentation => 'treex file names',
);

has 'glob' => (
    traits      => ['Getopt'],
    cmd_aliases => 'g',
    is          => 'rw',
    isa => 'Str',
    documentation => q{Input file mask whose expansion is to Perl, e.g. --glob '*.treex'},
);

has 'scenario'  => (
    traits => ['NoGetopt'],
    is => 'rw', isa => 'Treex::Core::Scenario',
    documentation => 'scenario object',
);


has 'parallel' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'p',
    is            => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'parallelize the task on SGE cluster (using qsub)',
);


has 'jobs' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'j',
    is            => 'ro',
    isa => 'Int',
    default =>  10 ,
    documentation => 'number of jobs for parallelization, default 10',
);

has 'qsub' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa => 'String',
    documentation => 'additional parameters passed to qsub',
);


sub _usage_format {
    return "usage: %c %o scenario [-- treex_files]\nscenario is a sequence of blocks or *.scen files\noptions:";
}

sub BUILD {
    # more complicated tests on consistency of options will be place here
    my ($self) = @_;
    my @file_sources;
    if ($self->filelist) {
	push @file_sources, "filelist option";
    }
    if ($self->filenames) {
	push @file_sources, "files after --";
    }
    if ($self->glob) {
	push @file_sources, "glob option";
    }
    if (@file_sources > 1) {
	log_fatal "At most one way to specify input files can be used. You combined ".(join " and ",@file_sources).".";

    }
}


sub execute {
    my ($self) = @_;
    my $scen_str = join ' ', @{ $self->extra_argv };

    if ( $self->glob ) {
	my @files = glob $self->glob;
	log_fatal 'No files matching mask \''.$self->glob.'\'\n' if @files == 0;
	$self->set_filenames( \@files );
    }
    elsif ($self->filelist) {
	open my $FL,"<:utf8",$self->filelist or log_fatal "Cannot open file list ".$self->filelist;
	my @files;
	while (<$FL>) {
	    chomp;
	    push @files,$_;
	}
	log_fatal 'No files matching mask \''.$self->glob.'\'\n' if @files == 0;
	$self->set_filenames( \@files );
    }

    if ( $self->filenames ) {
	log_info "Block Read added at the beginning of the scenario.";
        $scen_str = 'Read from=' . join( ',', @{ $self->filenames } ) . " $scen_str";
    }

    if ( $self->save ) {
	log_info "Block Write::Treex added at the end of the scenario."; 
        $scen_str .= ' Write::Treex';
    }

    if ($self->lang){
        $scen_str = 'SetGlobal language=' . $self->lang . " $scen_str";
    }

    print "QQQ new scen str: $scen_str\n";

    $self->set_scenario( Treex::Core::Scenario->new( { from_string => $scen_str } ) );
    $self->scenario->run();
}

1;

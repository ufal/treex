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
    is            => 'rw', isa => 'String',
    documentation => 'TODO load a list of treex files from a file',
);

has 'filenames' => ( traits => ['NoGetopt'], is => 'rw', isa => 'ArrayRef[Str]',         documentation => 'treex file names', );
has 'scenario'  => ( traits => ['NoGetopt'], is => 'rw', isa => 'Treex::Core::Scenario', documentation => 'scenario object', );

sub _usage_format {
    return "usage: %c %o scenario [-- treex_files]\nscenario is a sequence of blocks or *.scen files\noptions:";
}

sub execute {
    my ($self) = @_;
    my $scen_str = join ' ', @{ $self->extra_argv };
    if ( $self->save ) {
        $scen_str .= ' Write::Treex';
    }
    if ( $self->filenames ) {
        $scen_str = 'Read from=' . join( ',', @{ $self->filenames } ) . " $scen_str";
    }
    if ($self->lang){
        $scen_str = 'SetGlobal language=' . $self->lang . " $scen_str";
    }

    $self->set_scenario( Treex::Core::Scenario->new( { from_string => $scen_str } ) );
    $self->scenario->run();
}

1;

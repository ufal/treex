package Treex::Tool::IR::ESA;

use Moose;
use Treex::Core::Common;

use Treex::Tool::ProcessUtils;
use IPC::Open3;
use List::Util qw/min/;

has '_javain' => (
    is => 'ro',
    isa => 'FileHandle',
    writer => '_set_javain',
);

has '_javaout' => (
    is => 'ro',
    isa => 'FileHandle',
    writer => '_set_javaout',
);

has '_javaerr' => (
    is => 'ro',
    isa => 'FileHandle',
    writer => '_set_javaerr',
);

sub BUILD {
    my ($self) = @_;
    
    my $javain_h;
    my $javaout_h;
    #my $javaerr_h = 'gensym';

# TODO: Treex::Core::Resource::require_file_from_share

    my $java_path = $ENV{TMT_ROOT} . "/share/installed_tools/esalib";
    my $java_cmd = "( cd $java_path; java -Xmx5g -cp lib/*:esalib_ext.jar clldsystem.esa.ESAVector )";
    #my $java_cmd = "/home/mnovak/projects/tectomt/treex/lib/Treex/ahoj.pl";

    #IPC::Open3::open3($javain_h, $javaout_h, \*JAVAERR, $java_cmd);
    my $pid;
    ($javaout_h, $javain_h, $pid) = Treex::Tool::ProcessUtils::bipipe($java_cmd);
    
    my $esa_line = <$javaout_h>;
    if ($esa_line !~ /READY/) {
        log_fatal "Unable to execute ESA app.";
    }

    $self->_set_javain( $javain_h );
    $self->_set_javaout( $javaout_h );
    #$self->_set_javaerr( $javaerr_h );
}

sub esa_vector_n_best {
    my ($self, $text_str, $n_best) = @_;

    my ($javain_h, $javaout_h, $javaerr_h) = map {$self->$_} qw/_javain _javaout _javaerr/;

    print $javain_h "$text_str\n";
    
    my $esa_line = <$javaout_h>;
    return () if (!defined $esa_line);

    #return () if (!defined $esa_line || $esa_line =~ /^\s*$/);
    chomp $esa_line;
    my @items = split / /, $esa_line;
    my $max = scalar @items;
    if ($n_best) {
        $max = min( scalar @items, $n_best );
    }

    my %vector = map {split /:/, $_} @items[0 .. $max-1];
    return %vector;
}

1;

package Treex::Tool::Parser::Malt;
use Moose;
use Treex::Core::Common;

use Treex::Tool::ProcessUtils;
use File::Temp qw /tempdir/;

has model      => ( isa => 'Str', is => 'rw', required => 1);
has memory     => ( isa => 'Str',  is => 'rw', default => '10g' );


sub BUILD {
    my ($self) = @_;

    my $bindir = Treex::Core::Config->share_dir."/installed_tools/malt_parser/maltparser-1.8.1";
    my $maltjar = "$bindir/maltparser-1.8.1.jar";
    die "Missing $maltjar\n" if !-f $maltjar;

    my $model_path = $self->model;
    if (!-e $model_path) {
        $model_path = Treex::Core::Config->share_dir."/data/models/malt_parser/$model_path";
    }
    die "Missing $model_path\n" if !-e $model_path;

    my $model_name = $self->model;
    $model_name =~ s/^.+\///;

    my ( $reader, $writer, $pid );

    # create temporary working directory
    my $workdir = tempdir(Treex::Core::Config->tmp_dir."/maltparserXXXX", CLEANUP => 1);

    # symlink to the model (model has to be in working directory)
    # The symlinked path must be absolute unless we want a loop such as "malt.mco -> malt.mco"!
    my $abs_model_path = absolutize_path($model_path);
    system "ln -s $abs_model_path $workdir/$model_name";

    my $command = "cd $workdir; java -Xmx".$self->memory." -jar $maltjar -c $model_name";

    # start MaltParser
    ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $command );
    $self->{mpreader} = $reader;
    $self->{mpwriter} = $writer;
    $self->{mppid}    = $pid;

    return;
}

sub parse {
    my ( $self, $forms, $lemmas, $pos, $subpos, $features ) = @_;

    my $writer = $self->{mpwriter};
    my $reader = $self->{mpreader};

    my $cnt = scalar @$forms;
    if ( $cnt != scalar @$lemmas || $cnt != scalar @$pos || $cnt != scalar @$subpos || $cnt != scalar @$features ) {
        return 0;
    }

    # write input
    for ( my $i = 0; $i < $cnt; $i++ ) {
        print $writer ($i+1) . "\t$$forms[$i]\t$$lemmas[$i]\t$$pos[$i]\t$$subpos[$i]\t$$features[$i]\n";
    }
    print $writer "\n";

    # read output
    my @parents = ();
    my @afuns = ();
    while ( $cnt > 0 ) {
        my $got = <$reader>;
        chomp $got;
        my @items = split( /\t/, $got );
        $cnt--;
        push @parents, $items[6];
        push @afuns, $items[7];
    }

    # read empty line
    <$reader>;

    return ( \@parents, \@afuns );
}



#==============================================================================
# Functions to get absolute paths. (Copied from Dan Zeman's dzsys.pm.)
#==============================================================================



#------------------------------------------------------------------------------
# Figures out the current absolute path. If we want to know the caller's path
# we must call this before we change the current folder.
#------------------------------------------------------------------------------
sub get_current_path
{
    my $mydir = `pwd`;
    $mydir =~ s/\r?\n$//;
    return $mydir;
}



#------------------------------------------------------------------------------
# Figures out the absolute path to the script.
#------------------------------------------------------------------------------
sub get_script_path
{
    my $scriptdir = $0;
    # Strip script name, leave path to its folder.
    if($scriptdir !~ m-/-)
    {
        $scriptdir = ".";
    }
    else
    {
        # Remove the rightmost slash and everything after it.
        $scriptdir =~ s-/[^/]*$--;
    }
    my $current_path = get_current_path();
    chdir("$scriptdir") or die("Cannot change to $scriptdir folder: $!\n");
    $scriptdir = `pwd`;
    $scriptdir =~ s/\r?\n$//;
    chdir($current_path) or die("Cannot change to $current_path folder: $!\n");
    return $scriptdir;
}



#------------------------------------------------------------------------------
# Concatenates two paths. If the right path is absolute, the left path is
# ignored. Otherwise, the right path is relative to the left path (which could
# be relative as well).
#------------------------------------------------------------------------------
sub join_paths
{
    my $left = shift;
    my $right = shift;
    if($right =~ m-^/-)
    {
        return $right;
    }
    else
    {
        $left =~ s-/$--;
        return $left."/".$right;
    }
}



#------------------------------------------------------------------------------
# Makes a relative path absolute. Joins the absolute current path.
#------------------------------------------------------------------------------
sub absolutize_path
{
    my $path = shift;
    return join_paths(get_current_path(), $path);
}


1;

__END__


=head1 NAME

Treex::Tools::Parser::Malt

=head1 SYNOPSIS

  my $parser = Parser::Malt::MaltParser->new({model => 'modelname'});
  my ( $parent_indices, $afuns ) = $parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );

=cut

# Copyright 2009-2011 David Mareček, Dan Zeman
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

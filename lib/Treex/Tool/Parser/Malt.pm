package Treex::Tool::Parser::Malt;
use Moose;
use Treex::Core::Common;

use ProcessUtils;
use File::Java;
use File::Temp qw /tempdir/;

has model      => ( isa => 'Str', is => 'rw', required => 1);
has memory     => ( isa => 'Str',  is => 'rw', default => '5000m' );


sub BUILD {
    my ($self) = @_;

    my $bindir = "$ENV{TMT_ROOT}/share/installed_tools/malt_parser";
    die "Missing $bindir\n" if !-d $bindir;

    my $model_path = $self->model;
    if (!-e $model_path) {
        $model_path = "$ENV{TMT_ROOT}/share/data/models/malt_parser/$model_path";
    }
    die "Missing $model_path\n" if !-e $model_path;

    my $model_name = $self->model;
    $model_name =~ s/^.+\///;

    my ( $reader, $writer, $pid );

    # create temporary working directory
    my $workdir = tempdir(Treex::Core::Config->tmp_dir."/maltparserXXXX", CLEANUP => 1);

    # symlink to the model (model has to be in working directory)
    system "ln -s $model_path $workdir/$model_name";

    my $command = "cd $workdir; java -Xmx".$self->memory." -jar $bindir/malt-1.5/malt.jar -c $model_name";

    # start MaltParser
    ( $reader, $writer, $pid ) = ProcessUtils::bipipe( $command );
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


1;

__END__


=head1 NAME

Treex::Tools::Parser::Malt

=head1 SYNOPSIS

  my $parser = Parser::Malt::MaltParser->new({model => 'modelname'});
  my ( $parent_indices, $afuns ) = $parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );

=cut

# Copyright 2009-2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.


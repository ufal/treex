package Treex::Tools::Parser::Malt;
use Moose;
use Treex::Core::Common;

use ProcessUtils;
use File::Java;
use File::Temp qw /tempdir/;

has model      => ( isa => 'Str', is => 'rw', required => 1);
has memory     => ( isa => 'Str',  is => 'rw', default => '1800m' );


sub BUILD {
    my ($self) = @_;

    my $bindir = "$ENV{TMT_ROOT}/share/installed_tools/malt_parser";
    die "Missing $bindir\n" if !-d $bindir;

    my $modeldir = "$ENV{TMT_ROOT}/share/data/models/malt_parser";
    die "Missing $modeldir\n" if !-d $model_dir;

    my ( $reader, $writer, $pid );

    # create temporary working directory
    my $workdir = tempdir("maltparserXXXX", CLEANUP=>1, DIR=>".");

    # symlink to the model (model has to be in working directory)
    system "ln -s $model_dir/$model.mco $workdir/$model.mco";

    my $command = "cd $workdir; java -jar $parser_dir/malt-1.3/malt.jar -c $model";

    # start MaltParser
    ( $reader, $writer, $pid ) = ProcessUtils::bipipe( $command );
    $self->{mpreader} = $reader;
    $self->{mpwriter} = $writer;
    $self->{mppid}    = $pid;

    return;
}

sub parse {
    my ( $self, $forms, $lemmas, $pos, $subpos, $fetaures ) = @_;
    
    my $writer = $self->{mpwriter};
    my $rdeader = $self->{mpreader};

    my $cnt = scalar @$forms;
    if ( $cnt != scalar @$tags || $cnt != scalar @$lemmas ) {
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

  my $parser = Parser::Malt::MaltParser->new(model => 'modelname');
  my ( $parent_indices, $afuns ) = $parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );

=cut

# Copyright 2009-2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.


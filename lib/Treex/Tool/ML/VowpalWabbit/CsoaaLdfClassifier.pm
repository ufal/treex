package Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier;

use Moose;
use Treex::Tool::ProcessUtils;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);


has 'vw_path' => ( is => 'ro', isa => 'Str', required => 1, default => '/home/odusek/work/tools/vowpal_wabbit/vowpalwabbit/vw' );

has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );

has 'model_path' => ( is => 'ro', isa => 'Str', required => 1 );

# Max. number of classes for VW
has 'ring_size' => ( is => 'ro', isa => 'Int', default => 512 );

sub BUILD {
    my ($self) = @_;

    my $model_path = $self->_locate_model_file( $self->model_path, $self );
    my $command = sprintf "%s --ring_size %d -t -i %s -p /dev/stdout 2> /dev/null", $self->vw_path, $self->ring_size, $model_path;

    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);

    $read->autoflush();
    $write->autoflush();
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
}

sub _locate_model_file {
    my ( $self, $path ) = @_;

    if ( !-f $path ) {
        $path = require_file_from_share( $path, ref($self) );
    }
    log_fatal 'File ' . $path . ' does not exist.' if !-f $path;
    return $path;
}

sub classify {
    my ( $self, $instance_str ) = @_;
    
    print { $self->_write_handle } $instance_str;

    my $fh = $self->_read_handle;
    my $class = undef;

    while ( my $line = <$fh> ) {
        chomp $line;
        last if ( $line =~ /^\s*$/ );
        my ( $select, $label ) = split / /, $line, 2;
        if ( $select > 0 ){
            $class = $label;
        }
    }
    return $class;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier

=head1 DESCRIPTION

A wrapper for VowpalWabbit's cost-sensitive one-against-all setting.

=head1 PARAMETERS

=over

=item vw_path

Path to an installation of VowpalWabbit -- the default only works on ÚFAL's internal network;
set this to your installation path.

=item model_path 

Path to a trained VowpalWabbit model

=item ring_size

Max. number of classes that VW will be given in the classification (default: 512).

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


package Treex::Tool::Storage::Storable;

use Moose::Role;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);

use File::Slurp;
use Compress::Zlib;

requires 'freeze';
requires 'thaw';

sub _locate_model_file {
    my ($self, $path) = @_;
    
    if (!-f $path) {
        $path = require_file_from_share($path, ref($self));
    }
    log_fatal 'File ' . $path . ' does not exist.' 
        if !-f $path;
    return $path;
}

sub load {
    my ($self, $filename) = @_;

    $filename = $self->_locate_model_file($filename);
    $self->load_specified($filename);
}

sub load_specified {
    my ($self, $filename) = @_;
    
    my $buffer = load_obj($filename);
    $self->thaw($buffer);
}

sub save {
    my ($self, $filename) = @_;
    
    my $buffer = $self->freeze();
    save_obj($buffer, $filename);
}

################ STATIC METHODS ######################

sub load_obj {
    my ($filename) = @_;
    my $obj = Compress::Zlib::memGunzip(read_file( $filename )) ;
    $obj = Storable::thaw($obj) or log_fatal $!;
    return $obj;
}

sub save_obj {
    my ($obj, $filename) = @_;
    
    $obj = Storable::nfreeze($obj) or log_fatal $!;
    write_file( $filename, {binmode => ':raw'},
        Compress::Zlib::memGzip($obj) )
    or log_fatal $!;
}

1;
__END__

# TODO fill in POD

=encoding utf-8

=head1 NAME

Treex::Tool::Storage::Storable

=head1 DESCRIPTION


=head1 METHODS

=over

=item save

=item load

=back

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item freeze

=item thaw

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

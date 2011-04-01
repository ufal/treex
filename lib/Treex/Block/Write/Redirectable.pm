package Treex::Block::Write::Redirectable;

use Moose::Role;
use autodie; # die if the output file cannot be opened

has to => (
    isa           => 'Str',
    is            => 'ro',
    default       => '-',
    documentation => 'the destination filename (standard output if nothing given)',
);

has encoding => (
    isa => 'Str',
    is => 'ro',
    default => 'utf8',
    documentation => 'Output encoding. \'utf8\' by default.',    
);

has _file_handle => (
    isa           => 'FileHandle',
    is            => 'rw',
    lazy_build    => 1,
    builder       => '_build_file_handle',
    documentation => 'the open output file handle',
);


sub _build_file_handle {

    my ($this) = @_;

    if ( $this->to ne "-" ) {
        open( my $fh, '>:utf8', $this->to );
        return $fh;
    }
    else {
        return \*STDOUT;
    }
}

sub DEMOLISH {

    my ($this) = @_;
    if ( $this->to ) {
        close( $this->_file_handle );
    }
    return;
}


1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::Redirectable

=head1 DESCRIPTION

A Moose role for Write blocks that can be redirected to a file. All blocks using this role must C<print> using the 
C<_file_handle> attribute. 

=head1 PARAMETERS

=over

=item C<to>

The name of the output file, STDOUT by default.

=item C<encoding>

The output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

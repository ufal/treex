package Treex::Core::TredView::BackendStorable;

package Treex::PML::Backend::Treex::Core::TredView::BackendStorable;

use strict;
use warnings;

use Treex::Core::Log;
use Treex::Core;
use Treex::PML::IO qw( close_backend);

use UNIVERSAL::DOES;

sub test {
    my ( $filename, $encoding )=@_;
    return $filename =~ /\.streex$/;
}

sub open_backend {
    my ( $filename ) = @_;
    open my $FILEHANDLE, "<:gzip",  $filename or log_fatal($!); # only for reading so far
    return $FILEHANDLE;
}

sub read { ## no critic (ProhibitBuiltinHomonyms)

    my ($filehandle,$pmldoc)=@_;
    my $doc = Treex::Core::Document->retrieve_storable($filehandle);
    my $restore = $doc->_pmldoc;

    # moving the data from the retrieved document to the prepared empty document
    @{$pmldoc} = @{$restore};

    # this is a hack for passing the already created Treex::Core structure up to TredView modules;
    # God knows what the 13th slot is, probably it's a slot for some application data
    $pmldoc->[13]->{_treex_core_document} = $doc;
    return;
}


sub write { ## no critic (ProhibitBuiltinHomonyms)
    my ($fd,$fs)=@_;
    log_fatal "Saving of .streex files in TrEd not implemented yet";
}


1;
__END__


=pod

=encoding utf-8

=head1 NAME

Treex::Core::TredView::Backend::Storable - I/O backend for opening .streex files in TrEd

=head1 DESCRIPTION

.streex files are gzipped data dumps of Treex::Core::Documents created by the Storable module.
This backend is based on Peter Pajas' Treex::PML::Backend::Storable.

=head1 SYNOPSIS

  $ tred -B Treex::Core::TredView::Backend::Storable ...

=head1 AUTHOR

Zdeněk Žabokrtský <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

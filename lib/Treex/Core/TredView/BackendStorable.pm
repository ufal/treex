package Treex::Core::TredView::BackendStorable;

package Treex::PML::Backend::Treex::Core::TredView::BackendStorable;

use strict;
use warnings;

use Treex::Core::Log;
use Treex::Core;
use Treex::PML::IO qw( close_backend);

use UNIVERSAL::DOES;
use Scalar::Util qw(blessed reftype refaddr);

sub test {
    my ( $filename, $encoding )=@_;
    print "XXX tested file: $filename\n";
    return $filename =~ /\.streex$/;
}

sub open_backend {
    #  Treex::PML::IO::open_backend(@_[0,1]);
    my ( $filename ) = @_;
    open my $FILEHANDLE, "<:gzip",  $filename or log_fatal($!); # only for reading so far
    return $FILEHANDLE;
}

sub read {

    my ($filehandle,$pmldoc)=@_;
    binmode($filehandle);

    my $doc = Treex::Core::Document->retrieve_storable($filehandle);

    my $restore = $doc->_pmldoc;

    $pmldoc->changeTail(@{$restore->[2]});
    $pmldoc->[13]=$restore->[3]; # metaData
    my $appData = delete $pmldoc->[13]->{'StorableBackend:savedAppData'};
    if ($appData) {
        $pmldoc->changeAppData($_,$appData->{$_}) foreach keys(%$appData);
    }
    $pmldoc->changePatterns(@{$restore->[4]});
    $pmldoc->changeHint($restore->[5]);

    # place to update some internal stuff if necessary
    my $schema = $pmldoc->metaData('schema');
    if (ref($schema) and !$schema->{-api_version}) {
        $schema->convert_from_hash();
        $schema->post_process();
    }
    $pmldoc->changeFS($restore->[0]);
    $pmldoc->changeTrees(@{$restore->[1]});
    $pmldoc->FS->renew_specials();

    #  $fs->_weakenLinks;
}


sub write {
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

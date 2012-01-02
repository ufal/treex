package Treex::Block::Write::ToBundleAttr;

use Moose::Role;
use Treex::Core::Log;
use autodie;

has to_bundle_attr => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'Set to an attribute name and the string per bundle will go there.',
);

before 'process_document' => sub {

    my ($self) = @_;

    if ( defined $self->to_bundle_attr ) {

        # just call the main process_document, we will hopefully get our
        # callback at process_bundle
        log_info "Saving to attribute " . $self->to_bundle_attr;
    }
    return;
};

around 'process_bundle' => sub {

    my ( $orig, $self, $bundle ) = @_;

    if ( defined $self->to_bundle_attr ) {

        # Open a temp file handle redirected to string
        my $output = '';
        my $fh     = undef;
        open $fh, '>', \$output;    # we use autodie
        binmode( $fh, ":utf8" );
        $self->_file_handle($fh);

        # call the main process_bundle
        $self->$orig(@_);

        # Close the temp file handle
        close $fh;
        $self->_file_handle(undef);

        # Store the output
        chomp($output);
        $bundle->set_attr( $self->to_bundle_attr, decode( "utf8", $output ) );
    }
    else {

        # call the main process_bundle
        $self->$orig($bundle);
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::ToBundleAttr

=head1 DESCRIPTION

TODO

=head1 PARAMETERS

=over

=item C<to_bundle_attr>

=back

=head1 AUTHORS

Ondřej Bojar <bojar@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

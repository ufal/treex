package Treex::Block::Write::SgmMTEval;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '_doc_id' => ( is => 'rw', isa => 'Int', default => 1 );

has 'add_header' => ( is => 'ro', isa => 'Str', default => '' );

has 'set_id' => ( is => 'ro', isa => 'Str', default => 'set' );

has 'sys_id' => ( is => 'ro', isa => 'Str', default => '' );

override 'print_header' => sub {
    my ( $self, $doc ) = @_;

    $self->_set_doc_id(1);

    my $lang = $self->language;
    $lang = "cz" if ( $lang eq "cs" );

    my $sysid = $self->sys_id;
    if ($sysid eq ''){
        $sysid = '"ref"' if ( $self->selector eq "ref" );
    }
    if ($sysid ne ''){
        $sysid = ' sysid="' . $sysid . '"';
    }

    if ( $self->add_header ne '' ) {
        print { $self->_file_handle } '<' . $self->add_header .
            ' setid="' . $self->set_id . '" srclang="any" trglang="' . $lang . '">' . "\n";
    }

    print { $self->_file_handle } "<doc docid=\"" . $doc->full_filename . "\" genre=\"news\" origlang=\"$lang\"$sysid>\n";
    print { $self->_file_handle } "<p>\n";
};

override 'print_footer' => sub {
    my ( $self, $doc ) = @_;

    print { $self->_file_handle } "</p>\n";
    print { $self->_file_handle } "</doc>\n";
    if ( $self->add_header ne '' ) {
        print { $self->_file_handle } '</' . $self->add_header . '>';
    }
};

sub process_zone {
    my ( $self, $zone ) = @_;

    print { $self->_file_handle } "<seg id=\"" . $self->_doc_id . "\">";
    print { $self->_file_handle } $zone->sentence;
    print { $self->_file_handle } "</seg>\n";

    $self->_set_doc_id( $self->_doc_id + 1 );
}

1;

__END__

=head1 NAME

Treex::Block::Write::SgmMTEval

=head1 DESCRIPTION

Prints sentences from the current zone in a a SGML format required by "mteval-v11b.pl" 
– the MT evaluation utility.

All sentences within a single document are put inside the same paragraph.

=head1 PARAMETERS

=over

=item add_header

Add the header tag of the given type, e.g. C<refset> or C<tstset>. If not given, no header tag
will be included in the output.

=item set_id

Add data set identification (defaults to C<set>).

=item sys_id

Add system identification. If this is empty and the current selector is set to C<ref>, the output
will be C<ref>. 

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

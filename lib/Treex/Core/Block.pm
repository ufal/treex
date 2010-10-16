package Treex::Core::Block;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;

has parameter => (is => 'rw');

sub process_stream {
    my ( $self, $stream ) = @_;
    $self->process_document($stream->get_current_document);
    # unimplemented
}


sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }
    return;
}

sub process_bundle {
#    Report::fatal "process_bundle() is not (and could not be) implemented"
#        . " in the abstract class TectoMT::Block !";
}

sub get_block_name {
    my ($self) = @_;
    return ref($self);
}

sub get_required_share_files {
    return ();
}

1;



__END__

=head1 NAME

TectoMT::Block !!!!!!!!!!!!! needs to be updated

=head1 SYNOPSIS

 package BlockGroup::My_Block;
 
 use strict; use warnings; use utf8;
 
 use base qw(TectoMT::Block);
 
 sub process_bundle {
    my ($self, $bundle) = @_;
    
    # processing
    
 }

=head1 DESCRIPTION

C<TectoMT::Block> is a base class serving as a common ancestor of
all TectoMT blocks.
C<TectoMT::Block> can't be used directly in any scenario.
Use it's descendants which implement method C<process_bundle()>
(or C<process_document()>) instead.

=head1 CONSTRUCTOR

=over 4

=item my $block = BlockGroup::My_Block->new();

Instance of a block derived from TectoMT::Block can be created
by the constructor (optionally, a reference to a hash of block parameters
can be specified as the constructor's argument, see BLOCK PARAMETRIZATION).
However, it is not likely to appear in your code since block initialization
is usually invoked automatically when initializing a scenario.

=back

=head1 METHODS FOR BLOCK EXECUTION

=over 4

=item $block->process_document($document);

Applies the block instance on the given instance of C<TectoMT::Document>.
The default implementation iterates over all bundles in a document
and calls C<process_bundle()>.
So in most cases you don't need to override this method.

=item $block->process_bundle($bundle);

Applies the block instance on the given bundle (C<TectoMT::Bundle>).
This is the method you must implement to make your block working
(unless you override C<process_document()>).

=item $block->process_stream($stream);

Applies the block instance on the given stream (C<TectoMT::Bundle>).


=back

=head1 BLOCK PARAMETRIZATION

=over 4

=item my $block = BlockGroup::My_Block->new({$name1=>$value1,$name2=>$value2...});

Block instances can be parametrized by a hash containing parameter name/value
pairs.

=item my $param_value = $block->get_parameter($param_name);

Parameter values used in block construction can
be revealed by get_parameter method (but cannot be changed).

=back

=head1 MISCEL

=over 4

=item my $block_name = $block->get_block_name();

It returns the name of the block module.

=item my @needed_files = $block->get_required_share_files();

If a block requires some files to be present in the shared part
of TectoMT, their list (with relative paths starting in $TMT_ROOT/share/) can be specified
by redefining by this method. By default, an empty list is returned. Presence
of the files is automatically checked in the block constructor. If some of
the required file is missing, the constructor tries to download it
from http://ufallab.ms.mff.cuni.cz.

This method should be used especially for downloading statistical models,
but not for installed tools or libraries.

 sub get_required_share_files {
     my $self = shift;
     return (
         'data/models/mytool/'.$self->get_parameter('LANGUAGE').'/features.gz',
         'data/models/mytool/'.$self->get_parameter('LANGUAGE').'/weights.tsv',
     );
 }


=back

=head1 SEE ALSO

L<TectoMT::Node|TectoMT::Node>,
L<TectoMT::Bundle|TectoMT::Bundle>,
L<TectoMT::Document|TectoMT::Document>,
L<TectoMT::Scenario|TectoMT::Scenario>,

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2006 Zdenek Zabokrtsky
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

